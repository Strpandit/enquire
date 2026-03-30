class DeviceInstallationBlueprint < Blueprinter::Base
  identifier :id

  fields :platform, :device_id, :active, :last_seen_at, :metadata, :created_at
end
