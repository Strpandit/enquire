module Api
  module V1
    class WithdrawalRequestsController < BaseController
      def index
        withdrawals = current_account.withdrawal_requests.recent.page(params[:page]).per(per_page)

        render json: {
          withdrawal_requests: WithdrawalRequestBlueprint.render_as_hash(withdrawals),
          earnings_balance: current_account.earnings_balance,
          pagination: pagination_meta(withdrawals)
        }, status: :ok
      end

      def create
        amount = params.require(:amount).to_i
        upi_id = params.require(:upi_id).to_s.strip

        raise ActionController::ParameterMissing, "Amount must be greater than 0" if amount <= 0

        withdrawal = nil
        current_account.with_lock do
          raise ActionController::ParameterMissing, "Insufficient earnings balance" if current_account.earnings_balance < amount

          withdrawal = current_account.withdrawal_requests.create!(
            amount: amount,
            upi_id: upi_id,
            status: :pending
          )
          current_account.update!(earnings_balance: current_account.earnings_balance - amount)
          ActivityLogger.log(account: current_account, event: "WITHDRAWAL_REQUEST", title: "Requested UPI payout of ₹#{amount} to #{upi_id}", metadata: { withdrawal_id: withdrawal.id, upi_id: upi_id }, ip_address: request.remote_ip)
        end

        render json: {
          message: "Withdrawal request submitted successfully",
          withdrawal_request: WithdrawalRequestBlueprint.render_as_hash(withdrawal),
          earnings_balance: current_account.earnings_balance
        }, status: :created
      rescue => error
        render_service_error(error)
      end

      def cancel
        withdrawal = current_account.withdrawal_requests.find(params[:id])

        current_account.with_lock do
          withdrawal.reload
          raise ActionController::ParameterMissing, "Only pending requests can be cancelled" unless withdrawal.pending?

          withdrawal.update!(status: :rejected, failure_reason: "Cancelled by user")
          current_account.update!(earnings_balance: current_account.earnings_balance + withdrawal.amount)
          ActivityLogger.log(account: current_account, event: "WITHDRAWAL_CANCEL", title: "Cancelled UPI payout request of ₹#{withdrawal.amount}", metadata: { withdrawal_id: withdrawal.id }, ip_address: request.remote_ip)
        end

        render json: {
          message: "Withdrawal request cancelled successfully",
          earnings_balance: current_account.earnings_balance
        }, status: :ok
      rescue => error
        render_service_error(error)
      end
    end
  end
end
