module PushNotifications
  class LogAdapter
    def deliver(notification:, installation:)
      Rails.logger.warn(
        "[PushNotifications][LogAdapter] NO PUSH SENT (FCM not configured). " \
        "notification_id=#{notification.id} type=#{notification.notification_type} " \
        "account_id=#{notification.recipient_account_id} platform=#{installation.platform} " \
        "token_prefix=#{installation.device_token.to_s[0, 12]}… title=#{notification.title.inspect}"
      )
      true
    end
  end
end
