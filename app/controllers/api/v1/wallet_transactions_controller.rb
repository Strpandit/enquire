module Api
  module V1
    class WalletTransactionsController < BaseController
      def index
        transactions = current_account.wallet_transactions.order(created_at: :desc).page(params[:page]).per(per_page)
        render json: {
          wallet_balance_cents: current_account.wallet_balance_cents,
          wallet_transactions: WalletTransactionBlueprint.render_as_hash(transactions),
          meta: pagination_meta(transactions)
        }, status: :ok
      end
    end
  end
end
