module Api
  module V1
    class CashfreePaymentsController < BaseController
      skip_before_action :authorize_request, only: [ :webhook ]

      def create
        purpose = params[:purpose].to_s.presence || "wallet"

        if purpose == "verification"
          amount = Account::VERIFICATION_PRICE
          order_id = "verify_#{current_account.id}_#{SecureRandom.hex(8)}"
          order_note = "Verification badge fee (180 days) for #{current_account.full_name}"
        else
          amount = params.require(:amount).to_i
          raise ActionController::ParameterMissing, "amount must be greater than 0" if amount <= 0

          order_id = "wallet_#{current_account.id}_#{SecureRandom.hex(8)}"
          order_note = "Wallet top-up for account #{current_account.id}"
        end

        checkout = Cashfree::PaymentService.create_order(
          amount: amount,
          order_id: order_id,
          customer: current_account,
          order_note: order_note
        )

        render json: checkout.merge(order_id: order_id, purpose: purpose, amount: amount), status: :ok
      rescue => error
        render_service_error(error)
      end

      def webhook
        payload = request.raw_post
        signature = request.headers["x-webhook-signature"] ||
                    request.headers["X-Cashfree-Signature"] ||
                    request.headers["HTTP_X_CASHFREE_SIGNATURE"]
        timestamp = request.headers["x-webhook-timestamp"]

        event = Cashfree::PaymentService.process_webhook!(payload: payload, signature: signature, timestamp: timestamp)

        return head :ok unless event[:status] == "PAID"

        if (account_id = event[:account_id]) && (account = Account.find_by(id: account_id))
          if event[:order_id].to_s.start_with?("wallet_")
            credit_wallet(account: account, order_id: event[:order_id], amount: event[:amount], source: "webhook")
          elsif event[:order_id].to_s.start_with?("verify_")
            ActivityLogger.log(
              account: account,
              event: "VERIFICATION_PAID",
              title: "Verification payment of ₹#{event[:amount]} received",
              metadata: { order_id: event[:order_id], amount: event[:amount] }
            )
          end
        end

        head :ok
      rescue Cashfree::PaymentService::Error => e
        Rails.logger.warn("[cashfree] webhook rejected: #{e.message}")
        head :bad_request
      end

      def verify
        order_id = params[:order_id].presence || params[:orderId].presence || params[:id].presence
        raise ActionController::ParameterMissing, "order_id is required" if order_id.blank?

        if Cashfree::PaymentService.extract_account_id(order_id) != current_account.id
          return render json: { errors: [ "This order does not belong to your account" ] }, status: :forbidden
        end

        result = Cashfree::PaymentService.get_order_status(order_id: order_id)

        if result[:order_status] == "PAID"
          is_verification = order_id.to_s.start_with?("verify_")

          unless is_verification
            credit_wallet(account: current_account, order_id: order_id, amount: result[:amount], source: "verify_endpoint", ip_address: request.remote_ip)
          end

          render json: {
            status: "success",
            purpose: is_verification ? "verification" : "wallet",
            message: is_verification ? "Verification payment verified successfully!" : "Payment verified and credited successfully!",
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
      rescue => error
        render_service_error(error)
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
