module PushNotifications
  class Dispatcher
    def initialize(notification)
      @notification = notification
    end

    def deliver!
      return false unless installations.exists?

      delivered = false
      installations.find_each do |installation|
        adapter.deliver(notification: notification, installation: installation)
        delivered = true
      rescue StandardError => e
        Rails.logger.error("[PushNotifications] delivery_failed notification_id=#{notification.id} installation_id=#{installation.id} error=#{e.class}: #{e.message}")
      end

      notification.update_column(:push_sent_at, Time.current) if delivered
      delivered
    end

    private

    attr_reader :notification

    def installations
      notification.recipient_account.device_installations.active.select(:id, :platform, :device_token)
    end

    def adapter
      @adapter ||= if ENV["FIREBASE_PROJECT_ID"].present? &&
                      (ENV["FIREBASE_SERVICE_ACCOUNT_JSON"].present? || ENV["FIREBASE_SERVICE_ACCOUNT_PATH"].present?)
        PushNotifications::FcmAdapter.new
      else
        PushNotifications::LogAdapter.new
      end
    end
  end
end
