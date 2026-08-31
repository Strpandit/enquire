module Api
  module V1
    class CashfreePaymentsController < BaseController
      skip_before_action :authorize_request, only: [:webhook]

      def create
        amount = params.require(:amount).to_i
        raise ActionController::ParameterMissing, "amount must be greater than 0" if amount <= 0

        order_id = "wallet_#{current_account.id}_#{SecureRandom.hex(8)}"
        checkout = Cashfree::PaymentService.create_order(amount: amount, order_id: order_id, customer: current_account)

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
          credit_wallet(account: account, order_id: event[:order_id], amount: event[:amount], source: "webhook")
        end

        head :ok
      end

      def verify
        order_id = params[:order_id].presence || params[:orderId].presence || params[:id].presence
        raise ActionController::ParameterMissing, "order_id is required" if order_id.blank?

        result = Cashfree::PaymentService.get_order_status(order_id: order_id)

        if result[:order_status] == "PAID"
          credit_wallet(account: current_account, order_id: order_id, amount: result[:amount], source: "verify_endpoint", ip_address: request.remote_ip)

          render json: {
            status: "success",
            message: "Payment verified and credited successfully!",
            order_id: order_id,
            amount: result[:amount],
            wallet_balance: current_account.reload.wallet_balance
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

      private

      def credit_wallet(account:, order_id:, amount:, source:, ip_address: nil)
        result = Wallets::LedgerService.credit!(
          account: account,
          amount: amount,
          description: "Wallet Top-Up",
          metadata: { order_id: order_id, source: source },
          idempotency_key: "cashfree_order_#{order_id}"
        )

        return if result.already_applied?

        ActivityLogger.log(account: account, event: "WALLET_TOPUP", title: "Added ₹#{amount} to wallet", metadata: { order_id: order_id }, ip_address: ip_address)
      end
    end
  end
end
