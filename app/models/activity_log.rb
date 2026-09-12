class ActivityLog < ApplicationRecord
  belongs_to :account, optional: true
  belongs_to :device, optional: true

  validates :event, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :user_visible, -> {
    where.not(event: [ "APP_BACKGROUND", "APP_FOREGROUND", "DEVICE_SYNC" ])
  }
end
