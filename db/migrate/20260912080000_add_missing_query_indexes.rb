class AddMissingQueryIndexes < ActiveRecord::Migration[8.0]
  def change
    add_index :business_profiles, [ :approval_status, :avg_rating, :created_at ],
              name: "index_business_profiles_on_status_rating_created"
    add_index :wallet_transactions, [ :account_id, :created_at ],
              name: "index_wallet_transactions_on_account_id_and_created_at"
  end
end
