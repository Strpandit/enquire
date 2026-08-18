class ActivityLogger
  def self.log(account:, event:, title:, metadata: {}, device: nil, ip_address: nil)
    return unless account.present?

    ActivityLog.create!(
      account: account,
      device: device,
      event: event,
      title: title,
      metadata: metadata || {},
      ip_address: ip_address
    )
  rescue StandardError => e
    Rails.logger.error("ActivityLogger Error: #{e.message}")
    nil
  end
end
