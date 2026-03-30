class WalletTransactionBlueprint < Blueprinter::Base
  identifier :id

  fields :account_id, :chat_session_id, :transaction_type, :amount_cents, :balance_after_cents, :entry_type,
         :reference_type, :reference_id, :description, :metadata, :created_at
end
