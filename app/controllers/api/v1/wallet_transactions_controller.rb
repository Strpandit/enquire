module Api
  module V1
    class WalletTransactionsController < BaseController
      def index
        return grouped_index if params[:grouped].to_s == "true"

        transactions = current_account.wallet_transactions.order(created_at: :desc).page(params[:page]).per(per_page)
        render json: {
          wallet_balance: current_account.wallet_balance,
          earnings_balance: current_account.earnings_balance,
          wallet_transactions: WalletTransactionBlueprint.render_as_hash(transactions),
          meta: pagination_meta(transactions)
        }, status: :ok
      end

      private

      def grouped_index
        result = Wallets::GroupedHistory.new(account: current_account, page: params[:page], per_page: per_page).call
        render json: {
          wallet_balance: current_account.wallet_balance,
          earnings_balance: current_account.earnings_balance,
          wallet_groups: result.groups,
          meta: { current_page: result.current_page, next_page: result.next_page, per_page: result.per_page }
        }, status: :ok
      end
    end
  end
end
