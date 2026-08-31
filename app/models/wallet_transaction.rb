class WalletTransaction < ApplicationRecord
  belongs_to :account
  belongs_to :chat_session, optional: true

  enum :transaction_type, { debit: 0, credit: 1 }

  ENTRY_TYPES = %w[chat call earnings manual].freeze

  validates :amount, numericality: { greater_than: 0, only_integer: true }
  validates :balance_after, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :entry_type, inclusion: { in: ENTRY_TYPES }
  validates :description, presence: true
  validates :idempotency_key, uniqueness: true, allow_nil: true
end
