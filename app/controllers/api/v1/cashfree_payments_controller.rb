module Api
  module V1
    class CashfreePaymentsController < BaseController
      skip_before_action :authorize_request, only: [:webhook]

      def create
        amount_cents = params.require(:amount_cents).to_i
        raise ActionController::ParameterMissing, "amount_cents must be greater than 0" if amount_cents <= 0

        order_id = "wallet_#{current_account.id}_#{SecureRandom.hex(8)}"
        checkout = Cashfree::PaymentService.create_order(amount_cents: amount_cents, order_id: order_id, customer: current_account)

        render json: checkout.merge(order_id: order_id), status: :ok
      rescue StandardError => error
        render json: { errors: [error.message] }, status: :unprocessable_entity
      end

      def webhook
        payload = request.raw_post
        signature = request.headers["X-Cashfree-Signature"] || request.headers["HTTP_X_CASHFREE_SIGNATURE"]
        event = Cashfree::PaymentService.process_webhook!(payload: payload, signature: signature)

        return head :ok unless event[:status] == "PAID"

        if (account_id = event[:account_id]) && (account = Account.find_by(id: account_id))
          Wallets::LedgerService.credit!(account: account, amount_cents: event[:amount_cents], description: "Cashfree wallet top-up", metadata: event.except(:amount_cents, :account_id))
        end

        head :ok
      rescue StandardError => error
        render json: { errors: [error.message] }, status: :unprocessable_entity
      end
    end
  end
end
