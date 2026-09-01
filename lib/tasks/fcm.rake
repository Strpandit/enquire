namespace :fcm do
  desc "Diagnose Firebase Cloud Messaging configuration (run on the server: `bin/rails fcm:doctor`)"
  task doctor: :environment do
    puts "== FCM Doctor =="
    puts "RAILS_ENV                     : #{Rails.env}"
    puts "FIREBASE_PROJECT_ID (env)     : #{ENV['FIREBASE_PROJECT_ID'].presence || '(not set)'}"
    puts "FIREBASE_SERVICE_ACCOUNT_JSON : #{ENV['FIREBASE_SERVICE_ACCOUNT_JSON'].present? ? "set (#{ENV['FIREBASE_SERVICE_ACCOUNT_JSON'].bytesize} bytes)" : '(not set)'}"
    path = ENV["FIREBASE_SERVICE_ACCOUNT_PATH"]
    puts "FIREBASE_SERVICE_ACCOUNT_PATH : #{path.presence || '(not set)'}#{path.present? ? " (exists=#{File.exist?(path)})" : ''}"
    file = Rails.root.join("config", "firebase_service_account.json")
    puts "config/firebase_service_account.json present : #{File.exist?(file)}"
    puts

    result = PushNotifications::FcmAdapter.new.diagnose!
    if result[:ok]
      puts "credential_source     : #{result[:credential_source]}"
      puts "project_id            : #{result[:project_id]}"
      puts "service_account_email : #{result[:service_account_email]}"
      puts "OAuth access token    : #{result[:access_token_present] ? 'OK — Google accepted the service account' : 'FAILED'}"
      puts
      puts "=> FCM credentials look good. Real pushes will be sent."
    else
      puts "credential_source : #{result[:credential_source]}"
      puts "ERROR             : #{result[:error]}"
      puts
      puts "=> FCM is NOT working. Every push is currently only written to the log."
      puts "   Fix: set FIREBASE_SERVICE_ACCOUNT_JSON (full JSON of the service account) and"
      puts "        FIREBASE_PROJECT_ID in the server environment, then redeploy."
    end

    puts
    active = DeviceInstallation.active.count
    total  = DeviceInstallation.count
    puts "device_installations : #{active} active / #{total} total"
    fake = DeviceInstallation.where("device_token LIKE 'push_%' OR device_token LIKE 'ExponentPushToken%' OR LENGTH(device_token) < 100").count
    puts "suspicious tokens    : #{fake} (fake/placeholder/too-short — these will never receive a push)" if fake.positive?
  end

  desc "Send a real test push to a device token: `bin/rails 'fcm:test[<device_token>]'`"
  task :test, [:token] => :environment do |_t, args|
    token = args[:token].presence || abort("Usage: bin/rails 'fcm:test[<device_token>]'")

    installation = DeviceInstallation.new(id: 0, platform: "android", device_token: token)
    notification = Notification.new(
      id: 0,
      recipient_account_id: 0,
      notification_type: "system_test",
      title: "PreviewTax test push",
      body: "If you can read this, FCM delivery works. #{Time.current.strftime('%H:%M:%S')}",
      payload: { test: true }
    )

    PushNotifications::FcmAdapter.new.deliver(notification: notification, installation: installation)
    puts "=> Sent. Check the device."
  rescue StandardError => e
    abort("FAILED: #{e.class}: #{e.message}")
  end
end
