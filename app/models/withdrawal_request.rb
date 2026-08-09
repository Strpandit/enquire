class WithdrawalRequest < ApplicationRecord
  belongs_to :account

  enum :status, { pending: 0, approved: 1, completed: 2, rejected: 3 }

  validates :account_id, :amount_cents, :upi_id, presence: true
  validates :amount_cents, numericality: { greater_than: 0, only_integer: true }
  validates :upi_id, format: { with: /\A[a-zA-Z0-9._-]+@[a-zA-Z0-9]+\z/, message: "format must be valid (example@bank)" }

  DEDUCTION_PERCENTAGE = 0.20

  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: [:pending, :approved]) }

  def amount
    amount_cents.to_i / 100.0
  end

  def deduction_amount_cents
    (amount_cents * DEDUCTION_PERCENTAGE).round
  end

  def net_amount_cents
    amount_cents - deduction_amount_cents
  end

  def deduction_amount
    deduction_amount_cents / 100.0
  end

  def net_amount
    net_amount_cents / 100.0
  end
end
