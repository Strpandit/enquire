class DeviceSession < ApplicationRecord
  belongs_to :account, optional: true
  belongs_to :device, optional: true

  scope :active, -> { where(logout_at: nil) }
end
