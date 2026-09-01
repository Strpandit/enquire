module PushNotifications
  class Dispatcher
    def initialize(notification)
      @notification = notification
    end

    def deliver!
      unless installations.exists?
        Rails.logger.warn(
          "[PushNotifications] no active device_installations for account_id=#{notification.recipient_account_id} " \
          "notification_id=#{notification.id} type=#{notification.notification_type} — nothing to push. " \
          "(The recipient has never registered a real FCM token, or every token was deactivated as stale.)"
        )
        return false
      end

      Rails.logger.info(
        "[PushNotifications] dispatching notification_id=#{notification.id} type=#{notification.notification_type} " \
        "account_id=#{notification.recipient_account_id} installations=#{installations.count} adapter=#{adapter.class.name}"
      )

      delivered = false
      installations.find_each do |installation|
        adapter.deliver(notification: notification, installation: installation)
        delivered = true
      rescue PushNotifications::FcmAdapter::InvalidTokenError => e
        installation.update_column(:active, false)
        Rails.logger.warn("[PushNotifications] deactivated stale installation_id=#{installation.id}: #{e.message}")
      rescue PushNotifications::FcmAdapter::ConfigurationError => e
        Rails.logger.error("[PushNotifications] FCM is misconfigured — push NOT sent. #{e.message}. Run `rails fcm:doctor` on the server.")
        break
      rescue StandardError => e
        Rails.logger.error(
          "[PushNotifications] delivery_failed notification_id=#{notification.id} installation_id=#{installation.id} " \
          "error=#{e.class}: #{e.message}\n#{Array(e.backtrace).first(5).join("\n")}"
        )
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
      @adapter ||= if fcm_configured?
        PushNotifications::FcmAdapter.new
      else
        Rails.logger.error(
          "[PushNotifications] FCM credentials NOT configured — falling back to LogAdapter. " \
          "Real push notifications are DISABLED. Set FIREBASE_SERVICE_ACCOUNT_JSON (+ FIREBASE_PROJECT_ID) " \
          "in the server environment. See `rails fcm:doctor`."
        )
        PushNotifications::LogAdapter.new
      end
    end

    def fcm_configured?
      return true if ENV["FIREBASE_SERVICE_ACCOUNT_JSON"].present?
      return true if ENV["FIREBASE_SERVICE_ACCOUNT_PATH"].present? && File.exist?(ENV["FIREBASE_SERVICE_ACCOUNT_PATH"])
      return true if Rails.application.credentials.dig(:firebase, :service_account_json).present?
      return true if Rails.root.join("config", "firebase_service_account.json").exist?

      false
    end
  end
end
