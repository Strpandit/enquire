class Device < ApplicationRecord
  belongs_to :account, optional: true
  has_many :device_sessions, dependent: :destroy
  has_many :activity_logs, dependent: :nullify

  validates :device_uuid, presence: true

  scope :active_today, -> { where("last_seen_at >= ?", Time.current.beginning_of_day) }
end
