ActiveAdmin.register_page "FCM Doctor" do
  menu priority: 2, label: "FCM Doctor (Push)"

  # POST target for the "send test push" form.
  page_action :send_test, method: :post do
    token = params[:device_token].to_s.strip
    account_id = params[:account_id].to_s.strip

    installations =
      if token.present?
        [DeviceInstallation.new(id: 0, platform: "android", device_token: token)]
      elsif account_id.present?
        DeviceInstallation.active.where(account_id: account_id).to_a
      else
        []
      end

    if installations.empty?
      redirect_to admin_fcm_doctor_path, alert: "No device token / no active installations for that account."
      next
    end

    notification = Notification.new(
      id: 0,
      recipient_account_id: account_id.presence || 0,
      notification_type: "system_test",
      title: "PreviewTax test push",
      body: "FCM delivery works ✅  #{Time.current.strftime('%d %b %H:%M:%S')}",
      payload: { test: "true" }
    )

    sent = 0
    errors = []
    installations.each do |inst|
      PushNotifications::FcmAdapter.new.deliver(notification: notification, installation: inst)
      sent += 1
    rescue StandardError => e
      errors << "#{inst.device_token.to_s[0, 16]}…: #{e.class}: #{e.message}"
    end

    if errors.empty?
      redirect_to admin_fcm_doctor_path, notice: "Test push sent to #{sent} device(s). Check the phone."
    else
      redirect_to admin_fcm_doctor_path, alert: "Sent #{sent}, failed #{errors.size}. #{errors.join(' | ')}"
    end
  end

  content title: "FCM Doctor — push notification diagnostics" do
    # ---- 1. Configuration / credentials -----------------------------------
    diag = PushNotifications::FcmAdapter.new.diagnose!

    panel "1. Server credentials" do
      rows = {
        "RAILS_ENV" => Rails.env,
        "FIREBASE_PROJECT_ID (env)" => (ENV["FIREBASE_PROJECT_ID"].presence || "(not set)"),
        "FIREBASE_SERVICE_ACCOUNT_JSON (env)" => (ENV["FIREBASE_SERVICE_ACCOUNT_JSON"].present? ? "set (#{ENV['FIREBASE_SERVICE_ACCOUNT_JSON'].bytesize} bytes)" : "(not set)"),
        "FIREBASE_SERVICE_ACCOUNT_PATH (env)" => (ENV["FIREBASE_SERVICE_ACCOUNT_PATH"].presence || "(not set)"),
        "credential_source" => diag[:credential_source],
        "resolved project_id" => diag[:project_id],
        "service account email" => diag[:service_account_email],
        "Google OAuth token" => (diag[:ok] && diag[:access_token_present] ? "OK — Google accepted the service account" : "FAILED"),
        "VERDICT" => (diag[:ok] ? "✅ FCM credentials look good — real pushes will be sent" : "❌ FCM NOT working — pushes only go to the log"),
        "error" => diag[:error].to_s
      }
      table do
        rows.each do |k, v|
          tr do
            th k, style: "text-align:left;padding:4px 12px;white-space:nowrap"
            td v.to_s, style: "padding:4px 12px"
          end
        end
      end
    end

    # ---- 2. Device installations ----------------------------------------
    panel "2. Registered devices" do
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

    # ---- 3. Recent push attempts (from Notification rows) ----------------
    panel "3. Recent notifications (push_sent_at shows if a push actually went out)" do
      table_for Notification.order(created_at: :desc).limit(20) do
        column("When") { |n| n.created_at.strftime("%d %b %H:%M") }
        column("To account") { |n| n.recipient_account_id }
        column("Type", &:notification_type)
        column("push_sent_at") { |n| n.try(:push_sent_at) ? n.push_sent_at.strftime("%H:%M:%S") : "— (not delivered)" }
      end
    end

    # ---- 4. Send a real test push --------------------------------------
    panel "4. Send a real test push" do
      form(action: admin_fcm_doctor_send_test_path, method: :post) do
        input(type: :hidden, name: :authenticity_token, value: form_authenticity_token.to_s)
        para do
          span "Device token (paste one): "
          input(type: :text, name: :device_token, style: "width:60%")
        end
        para do
          span "…or Account ID (sends to all its active devices): "
          input(type: :text, name: :account_id, style: "width:120px")
        end
        para { input(type: :submit, value: "Send test push") }
      end
    end
  end
end
