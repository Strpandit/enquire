class DeviceInstallation < ApplicationRecord
  belongs_to :account

  enum :platform, { android: 0, ios: 1, web: 2 }, default: :android

  validates :device_token, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }
end
