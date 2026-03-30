class WalletTransaction < ApplicationRecord
  belongs_to :account
  belongs_to :chat_session, optional: true

  enum :transaction_type, { debit: 0, credit: 1 }

  validates :amount_cents, numericality: { greater_than: 0, only_integer: true }
  validates :balance_after_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :entry_type, :description, presence: true
end
