class ChatSession < ApplicationRecord
  REQUEST_TIMEOUT = 2.minutes

  belongs_to :chat_conversation
  belongs_to :customer_account, class_name: "Account"
  belongs_to :business_profile

  has_many :chat_messages, dependent: :nullify
  has_many :wallet_transactions, dependent: :nullify

  enum :status, {
    requested: 0,
    active: 1,
    ended: 2,
    declined: 3,
    cancelled: 4,
    expired: 5
  }, default: :requested

  validates :price_per_minute_cents, numericality: { greater_than: 0, only_integer: true }
  validates :requested_at, presence: true
  validate :single_open_session_per_conversation

  scope :billable, -> { where(status: :active) }

  def ended?
    status.in?(%w[ended declined cancelled expired])
  end

  def expires_at
    requested_at + REQUEST_TIMEOUT
  end

  private

  def single_open_session_per_conversation
    return unless status.in?(%w[requested active])

    if self.class.where(chat_conversation_id: chat_conversation_id, status: [ :requested, :active ]).where.not(id: id).exists?
      errors.add(:base, "Only one open chat session is allowed per conversation")
    end
  end
end
