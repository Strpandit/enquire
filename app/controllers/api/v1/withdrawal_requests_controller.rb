module Api
  module V1
    class WithdrawalRequestsController < BaseController
      def index
        withdrawals = current_account.withdrawal_requests.recent.page(params[:page]).per(per_page)

        render json: {
          withdrawal_requests: WithdrawalRequestBlueprint.render_as_hash(withdrawals),
          earnings_balance_cents: current_account.earnings_balance_cents,
          pagination: pagination_meta(withdrawals)
        }, status: :ok
      end

      def create
        amount_cents = params.require(:amount_cents).to_i
        upi_id = params.require(:upi_id).to_s.strip

        raise ActionController::ParameterMissing, "Amount must be greater than 0" if amount_cents <= 0
        raise ActionController::ParameterMissing, "Insufficient earnings balance" if current_account.earnings_balance_cents < amount_cents

        withdrawal = nil
        ActiveRecord::Base.transaction do
          withdrawal = current_account.withdrawal_requests.create!(
            amount_cents: amount_cents,
            upi_id: upi_id,
            status: :pending
          )
          current_account.update!(earnings_balance_cents: current_account.earnings_balance_cents - amount_cents)
        end

        render json: {
          message: "Withdrawal request submitted successfully",
          withdrawal_request: WithdrawalRequestBlueprint.render_as_hash(withdrawal),
          earnings_balance_cents: current_account.earnings_balance_cents
        }, status: :created
      rescue StandardError => error
        render json: { errors: [error.message] }, status: :unprocessable_entity
      end

      def cancel
        withdrawal = current_account.withdrawal_requests.find(params[:id])
        raise ActionController::ParameterMissing, "Only pending requests can be cancelled" unless withdrawal.pending?

        ActiveRecord::Base.transaction do
          withdrawal.update!(status: :rejected, failure_reason: "Cancelled by user")
          current_account.update!(earnings_balance_cents: current_account.earnings_balance_cents + withdrawal.amount_cents)
        end

        render json: {
          message: "Withdrawal request cancelled successfully",
          earnings_balance_cents: current_account.earnings_balance_cents
        }, status: :ok
      rescue StandardError => error
        render json: { errors: [error.message] }, status: :unprocessable_entity
      end
    end
  end
end
