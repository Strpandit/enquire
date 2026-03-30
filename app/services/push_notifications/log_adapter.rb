module PushNotifications
  class LogAdapter
    def deliver(notification:, installation:)
      Rails.logger.info(
        "[PushNotifications] notification_id=#{notification.id} account_id=#{notification.recipient_account_id} platform=#{installation.platform} device_token=#{installation.device_token} title=#{notification.title.inspect}"
      )
      true
    end
  end
end
