class CallHistory < ApplicationRecord
  REQUEST_TIMEOUT = 40.seconds

  belongs_to :caller_account, class_name: "Account", foreign_key: "caller_account_id"
  belongs_to :receiver_account, class_name: "Account", foreign_key: "receiver_account_id"

  enum :status, { initiated: 0, active: 1, ended: 2, declined: 3, missed: 4, expired: 5 }
  enum :call_type, { voice: 0, video: 1 }

  validates :caller_account_id, :receiver_account_id, :channel_name, presence: true
  validates :amount_charged_cents, numericality: { greater_than_or_equal_to: 0 }

  scope :recent, -> { order(created_at: :desc) }
  scope :for_account, ->(account_id) { where("caller_account_id = ? OR receiver_account_id = ?", account_id, account_id) }

  def duration_formatted
    return "00:00" if duration_seconds.blank? || duration_seconds.zero?
    minutes = duration_seconds / 60
    seconds = duration_seconds % 60
    format("%02d:%02d", minutes, seconds)
  end

  def amount_charged
    amount_charged_cents.to_i / 100.0
  end
end
