class WithdrawalRequest < ApplicationRecord
  belongs_to :account

  enum :status, { pending: 0, approved: 1, completed: 2, rejected: 3 }

  MINIMUM_WITHDRAWAL = 500

  validates :account_id, :amount, :upi_id, presence: true
  validates :amount, numericality: { greater_than: 0, only_integer: true }
  validates :amount,
            numericality: { greater_than_or_equal_to: MINIMUM_WITHDRAWAL, message: "must be at least ₹#{MINIMUM_WITHDRAWAL}" },
            on: :create
  validates :upi_id, format: { with: /\A[a-zA-Z0-9._-]+@[a-zA-Z0-9]+\z/, message: "format must be valid (example@bank)" }

  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: [:pending, :approved]) }

  def deduction_amount
    0
  end

  def net_amount
    amount
  end
end
