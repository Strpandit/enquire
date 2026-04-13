class CreateCallHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :call_histories do |t|
      t.bigint "caller_account_id", null: false
      t.bigint "receiver_account_id", null: false
      t.string "call_type", default: "voice", null: false
      t.string "channel_name", null: false
      t.integer "duration_seconds", default: 0, null: false
      t.integer "amount_charged_cents", default: 0, null: false
      t.integer "status", default: 0, null: false
      t.datetime "started_at"
      t.datetime "ended_at"
      t.text "end_reason"
      t.json "metadata", default: {}
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["caller_account_id"], name: "index_call_histories_on_caller_account_id"
      t.index ["receiver_account_id"], name: "index_call_histories_on_receiver_account_id"
      t.index ["created_at"], name: "index_call_histories_on_created_at"
    end

    add_foreign_key "call_histories", "accounts", column: "caller_account_id"
    add_foreign_key "call_histories", "accounts", column: "receiver_account_id"
  end
end
