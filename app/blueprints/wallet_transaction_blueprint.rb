class WalletTransactionBlueprint < Blueprinter::Base
  identifier :id

  fields :account_id, :chat_session_id, :transaction_type, :amount, :balance_after, :entry_type,
         :reference_type, :reference_id, :description, :metadata, :created_at
end
