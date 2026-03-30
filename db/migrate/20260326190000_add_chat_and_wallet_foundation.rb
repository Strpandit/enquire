class AddChatAndWalletFoundation < ActiveRecord::Migration[8.0]
  def change

    add_column :accounts, :wallet_balance_cents, :integer, default: 0, null: false
    add_column :accounts, :uid, :string
    add_column :accounts, :last_seen_at, :datetime
    add_index :accounts, :uid, unique: true

    create_table :chat_conversations do |t|
      t.references :customer_account, null: false, foreign_key: { to_table: :accounts }
      t.references :business_profile, null: false, foreign_key: true
      t.integer :status, default: 0, null: false
      t.datetime :last_message_at
      t.text :last_message_preview
      t.datetime :last_read_by_customer_at
      t.datetime :last_read_by_business_at

      t.timestamps
    end

    add_index :chat_conversations, [ :customer_account_id, :business_profile_id ], unique: true, name: "idx_chat_conversations_on_customer_and_business"

    create_table :chat_sessions do |t|
      t.references :chat_conversation, null: false, foreign_key: true
      t.references :customer_account, null: false, foreign_key: { to_table: :accounts }
      t.references :business_profile, null: false, foreign_key: true
      t.integer :status, default: 0, null: false
      t.integer :price_per_minute_cents, null: false
      t.datetime :requested_at, null: false
      t.datetime :started_at
      t.datetime :ended_at
      t.datetime :last_billed_at
      t.integer :billable_seconds, default: 0, null: false
      t.integer :billed_minutes, default: 0, null: false
      t.integer :total_amount_cents, default: 0, null: false
      t.string :end_reason

      t.timestamps
    end

    add_index :chat_sessions, [ :chat_conversation_id, :status ], name: "idx_chat_sessions_on_conversation_and_status"

    create_table :chat_messages do |t|
      t.references :chat_conversation, null: false, foreign_key: true
      t.references :chat_session, foreign_key: true
      t.references :sender_account, null: false, foreign_key: { to_table: :accounts }
      t.integer :message_type, default: 0, null: false
      t.text :content, null: false
      t.datetime :sent_at, null: false
      t.datetime :read_at
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :chat_messages, [ :chat_conversation_id, :created_at ], name: "idx_chat_messages_on_conversation_and_created_at"

    create_table :wallet_transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :chat_session, foreign_key: true
      t.integer :transaction_type, null: false
      t.integer :amount_cents, null: false
      t.integer :balance_after_cents, null: false
      t.string :entry_type, null: false
      t.string :reference_type
      t.bigint :reference_id
      t.string :description, null: false
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :wallet_transactions, [ :reference_type, :reference_id ], name: "idx_wallet_transactions_on_reference"
  end
end
