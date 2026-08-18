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
          ActivityLogger.log(account: account, event: "WALLET_TOPUP", title: "Added ₹#{(event[:amount_cents] / 100.0).round(2)} to wallet via Cashfree", metadata: { order_id: event[:order_id] })
        end

        head :ok
      end
      
      def verify
        order_id = params[:order_id].presence || params[:orderId].presence || params[:id].presence
        raise ActionController::ParameterMissing, "order_id is required" if order_id.blank?

        result = Cashfree::PaymentService.get_order_status(order_id: order_id)

        if result[:order_status] == "PAID"
          tx_exists = current_account.wallet_transactions.exists?(reference_type: "CashfreeOrder", reference_id: order_id)
          unless tx_exists
            Wallets::LedgerService.credit!(
              account: current_account,
              amount_cents: result[:amount_cents],
              description: "Cashfree wallet top-up",
              metadata: { order_id: order_id, source: "verify_endpoint" }
            )
            ActivityLogger.log(account: current_account, event: "WALLET_TOPUP", title: "Added ₹#{(result[:amount_cents] / 100.0).round(2)} to wallet via Cashfree", metadata: { order_id: order_id }, ip_address: request.remote_ip)
          end

          render json: {
            status: "success",
            message: "Payment verified and credited successfully!",
            order_id: order_id,
            amount_cents: result[:amount_cents],
            wallet_balance_cents: current_account.reload.wallet_balance_cents
          }, status: :ok
        elsif result[:order_status] == "FAILED" || result[:order_status] == "USER_DROPPED" || result[:order_status] == "CANCELLED"
          render json: {
            status: "failed",
            message: "Payment was not completed or was cancelled.",
            order_id: order_id
          }, status: :ok
        else
          render json: {
            status: "pending",
            message: "Payment verification in progress.",
            order_id: order_id
          }, status: :ok
        end
      rescue StandardError => error
        render json: { errors: [error.message] }, status: :unprocessable_entity
      end
    end
  end
end
