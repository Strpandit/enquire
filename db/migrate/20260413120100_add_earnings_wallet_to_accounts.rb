class AddEarningsWalletToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :earnings_balance_cents, :integer, default: 0, null: false
    add_index :accounts, :earnings_balance_cents
  end
end
