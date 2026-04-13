class CreateWithdrawalRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :withdrawal_requests do |t|
      t.bigint "account_id", null: false
      t.integer "amount_cents", null: false
      t.string "upi_id", null: false
      t.integer "status", default: 0, null: false
      t.string "withdrawal_id"
      t.string "failure_reason"
      t.datetime "approved_at"
      t.datetime "completed_at"
      t.json "metadata", default: {}
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["account_id"], name: "index_withdrawal_requests_on_account_id"
      t.index ["status"], name: "index_withdrawal_requests_on_status"
    end

    add_foreign_key "withdrawal_requests", "accounts"
  end
end
