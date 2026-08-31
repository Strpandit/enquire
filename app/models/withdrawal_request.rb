class WithdrawalRequest < ApplicationRecord
  belongs_to :account

  enum :status, { pending: 0, approved: 1, completed: 2, rejected: 3 }

  validates :account_id, :amount, :upi_id, presence: true
  validates :amount, numericality: { greater_than: 0, only_integer: true }
  validates :upi_id, format: { with: /\A[a-zA-Z0-9._-]+@[a-zA-Z0-9]+\z/, message: "format must be valid (example@bank)" }

  DEDUCTION_PERCENTAGE = 0.20

  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: [:pending, :approved]) }

  def deduction_amount
    (amount * DEDUCTION_PERCENTAGE).round
  end

  def net_amount
    amount - deduction_amount
  end
end
