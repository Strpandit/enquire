ActiveAdmin.register_page "FCM Doctor" do
  menu priority: 2, label: "FCM Diagonsis"

  content title: "FCM push notification diagnostics" do
    panel "1. Registered devices" do
      active = DeviceInstallation.active.count
      total  = DeviceInstallation.count
      suspicious = DeviceInstallation.where(
        "device_token LIKE 'push_%' OR device_token LIKE 'ExponentPushToken%' OR device_token LIKE 'ExpoPushToken%' OR LENGTH(device_token) < 100"
      ).count

      para do
        b "#{active} active / #{total} total"
        span "  —  suspicious/fake tokens: #{suspicious}" if suspicious.positive?
      end
      para(style: "color:#b91c1c") { "No devices have registered a real FCM token yet. If users have the app open, the installed APK is missing the Firebase native module — rebuild & reinstall it." } if total.zero?

      if total.positive?
        table_for DeviceInstallation.order(updated_at: :desc).limit(25) do
          column("Account") { |i| i.account_id }
          column("Platform", &:platform)
          column("Token (prefix)") { |i| "#{i.device_token.to_s[0, 22]}…  (len #{i.device_token.to_s.length})" }
          column("Active", &:active)
          column("Last seen") { |i| i.try(:last_seen_at) || i.updated_at }
        end
      end
    end

    panel "2. Recent notifications (push_sent_at shows if a push actually went out)" do
      table_for Notification.order(created_at: :desc).limit(20) do
        column("When") { |n| n.created_at.strftime("%d %b %H:%M") }
        column("To account") { |n| n.recipient_account_id }
        column("Type", &:notification_type)
        column("push_sent_at") { |n| n.try(:push_sent_at) ? n.push_sent_at.strftime("%H:%M:%S") : "— (not delivered)" }
      end
    end
  end
end
