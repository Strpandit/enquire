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
        upi_id = params.require(:upi_id)

        raise ActionController::ParameterMissing, "Amount must be greater than 0" if amount_cents <= 0
        raise ActionController::ParameterMissing, "Earnings balance insufficient" if current_account.earnings_balance_cents < amount_cents

        withdrawal = current_account.withdrawal_requests.build(
          amount_cents: amount_cents,
          upi_id: upi_id,
          status: :pending
        )

        if withdrawal.save
          render json: {
            withdrawal_request: WithdrawalRequestBlueprint.render_as_hash(withdrawal)
          }, status: :created
        else
          render json: { errors: withdrawal.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActionController::ParameterMissing => error
        render json: { errors: [error.message] }, status: :unprocessable_entity
      end

      def cancel
        withdrawal = WithdrawalRequest.find(params[:id])
        raise ActionController::ParameterMissing, "Withdrawal not found" unless withdrawal
        raise ActionController::ParameterMissing, "You are not authorized" unless withdrawal.account_id == current_account.id
        raise ActionController::ParameterMissing, "Only pending withdrawals can be cancelled" unless withdrawal.pending?

        if withdrawal.update(status: :rejected)
          Wallets::LedgerService.credit!(
            account: current_account,
            amount_cents: withdrawal.amount_cents,
            description: "Withdrawal request cancelled",
            metadata: { withdrawal_id: withdrawal.id }
          )
          render json: { message: "Withdrawal cancelled successfully" }, status: :ok
        else
          render json: { errors: withdrawal.errors.full_messages }, status: :unprocessable_entity
        end
      rescue StandardError => error
        render json: { errors: [error.message] }, status: :unprocessable_entity
      end
    end
  end
end
