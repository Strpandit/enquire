class SimplifyMoneyToPlainRupees < ActiveRecord::Migration[8.0]
  def up
    rename_column :accounts, :wallet_balance_cents, :wallet_balance
    rename_column :accounts, :earnings_balance_cents, :earnings_balance

    if index_name_exists?(:accounts, "index_accounts_on_earnings_balance_cents")
      rename_index :accounts, "index_accounts_on_earnings_balance_cents", "index_accounts_on_earnings_balance"
    end

    rename_column :call_histories, :amount_charged_cents, :amount_charged

    rename_column :chat_sessions, :price_per_minute_cents, :price_per_minute
    rename_column :chat_sessions, :total_amount_cents, :total_amount

    rename_column :wallet_transactions, :amount_cents, :amount
    rename_column :wallet_transactions, :balance_after_cents, :balance_after

    rename_column :withdrawal_requests, :amount_cents, :amount

    change_column :business_profiles, :chat_price, :integer, using: "ROUND(chat_price)::integer"
    change_column :business_profiles, :call_price, :integer, using: "ROUND(call_price)::integer"
    change_column :business_profiles, :v_call_price, :integer, using: "ROUND(v_call_price)::integer"

    add_column :wallet_transactions, :idempotency_key, :string
    add_index :wallet_transactions, :idempotency_key, unique: true, where: "idempotency_key IS NOT NULL"

    add_index :chat_sessions, :chat_conversation_id, unique: true,
              where: "status IN (0, 1)", name: "idx_unique_open_chat_session_per_conversation"

    execute "UPDATE call_histories SET call_type = 'voice' WHERE call_type = '0'"
    execute "UPDATE call_histories SET call_type = 'video' WHERE call_type = '1'"
  end

  def down
    remove_index :chat_sessions, name: "idx_unique_open_chat_session_per_conversation"
    remove_index :wallet_transactions, :idempotency_key
    remove_column :wallet_transactions, :idempotency_key

    change_column :business_profiles, :chat_price, :decimal, precision: 8, scale: 2
    change_column :business_profiles, :call_price, :decimal, precision: 8, scale: 2
    change_column :business_profiles, :v_call_price, :decimal, precision: 8, scale: 2

    rename_column :withdrawal_requests, :amount, :amount_cents

    rename_column :wallet_transactions, :balance_after, :balance_after_cents
    rename_column :wallet_transactions, :amount, :amount_cents

    rename_column :chat_sessions, :total_amount, :total_amount_cents
    rename_column :chat_sessions, :price_per_minute, :price_per_minute_cents

    rename_column :call_histories, :amount_charged, :amount_charged_cents

    if index_name_exists?(:accounts, "index_accounts_on_earnings_balance")
      rename_index :accounts, "index_accounts_on_earnings_balance", "index_accounts_on_earnings_balance_cents"
    end
    rename_column :accounts, :earnings_balance, :earnings_balance_cents
    rename_column :accounts, :wallet_balance, :wallet_balance_cents
  end
end
