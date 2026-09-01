require "googleauth"
require "net/http"

module PushNotifications
  class FcmAdapter
    SCOPE = "https://www.googleapis.com/auth/firebase.messaging".freeze
    HIGH_PRIORITY_TYPES = %w[incoming_call call_declined call_missed chat_message message chat_request].freeze

    class InvalidTokenError < StandardError; end
    class ConfigurationError < StandardError; end

    def deliver(notification:, installation:)
      token = access_token
      request = build_request(token, installation.device_token, notification)

      Rails.logger.info(
        "[FCM] sending notification_id=#{notification.id} type=#{notification.notification_type} " \
        "installation_id=#{installation.id} account_id=#{notification.recipient_account_id} " \
        "token_prefix=#{installation.device_token.to_s[0, 12]}… project=#{project_id}"
      )

      response = http_client.request(request)

      if response.is_a?(Net::HTTPSuccess)
        Rails.logger.info("[FCM] delivered notification_id=#{notification.id} installation_id=#{installation.id} fcm_response=#{response.body.to_s.strip}")
        return true
      end

      if invalid_token_response?(response)
        raise InvalidTokenError, "FCM rejected device_token as invalid/unregistered (status=#{response.code}): #{response.body}"
      end

      Rails.logger.error(
        "[FCM] delivery_failed notification_id=#{notification.id} installation_id=#{installation.id} " \
        "http_status=#{response.code} body=#{response.body}"
      )
      raise "FCM push failed with status #{response.code}: #{response.body}"
    end

    def diagnose!
      json = service_account_json
      parsed = JSON.parse(json)
      token = access_token

      {
        ok: true,
        credential_source: credential_source,
        project_id: project_id,
        service_account_email: parsed["client_email"],
        access_token_present: token.present?
      }
    rescue StandardError => e
      { ok: false, credential_source: credential_source, project_id: project_id, error: "#{e.class}: #{e.message}" }
    end

    private

    def invalid_token_response?(response)
      return false unless %w[400 404].include?(response.code)

      body = JSON.parse(response.body)
      status = body.dig("error", "status")
      return true if %w[UNREGISTERED NOT_FOUND].include?(status)

      status == "INVALID_ARGUMENT" &&
        Array(body.dig("error", "details")).any? { |d| d.dig("fieldViolations")&.any? { |fv| fv["field"] == "message.token" } }
    rescue JSON::ParserError
      false
    end

    def build_request(token, device_token, notification)
      request = Net::HTTP::Post.new(endpoint)
      request["Authorization"] = "Bearer #{token}"
      request["Content-Type"] = "application/json; charset=UTF-8"
      request.body = message_body(device_token, notification).to_json
      request
    end

    def message_body(device_token, notification)
      type = notification.notification_type.to_s
      is_call = (type == "incoming_call")
      high_priority = HIGH_PRIORITY_TYPES.include?(type)

      message = {
        token: device_token,
        data: notification_payload(notification),
        android: {
          priority: high_priority ? "high" : "normal",
          ttl: is_call ? "45s" : "2419200s"
        }
      }

      if is_call
        # DATA-ONLY for calls: no `notification` block, so the app's background
        # handler always runs and renders the full-screen call UI itself
        # (Notifee). A `notification` block here would cause a duplicate,
        # non-full-screen OS notification.
        message[:data]["fcm_call"] = "1"
      else
        message[:notification] = { title: notification.title, body: notification.body }
        message[:android][:notification] = {
          channel_id: "default",
          notification_priority: high_priority ? "PRIORITY_HIGH" : "PRIORITY_DEFAULT",
          default_sound: true
        }
      end

      { message: message }
    end

    def notification_payload(notification)
      (notification.payload || {}).transform_values(&:to_s).merge(
        "notification_id" => notification.id.to_s,
        "notification_type" => notification.notification_type.to_s,
        "type" => notification.notification_type.to_s,
        "title" => notification.title.to_s,
        "body" => notification.body.to_s
      )
    end

    def endpoint
      @endpoint ||= URI("https://fcm.googleapis.com/v1/projects/#{project_id}/messages:send")
    end

    def project_id
      @project_id ||= ENV["FIREBASE_PROJECT_ID"].presence ||
                      Rails.application.credentials.dig(:firebase, :project_id).presence ||
                      begin
                        JSON.parse(service_account_json)["project_id"]
                      rescue StandardError
                        nil
                      end ||
                      raise(ConfigurationError, "FIREBASE_PROJECT_ID is not set and could not be derived from the service account")
    end

    def http_client
      @http_client ||= Net::HTTP.start(endpoint.host, endpoint.port, use_ssl: true, open_timeout: 5, read_timeout: 10)
    end

    def access_token
      authorization.fetch_access_token!["access_token"]
    end

    def authorization
      @authorization ||= Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: StringIO.new(service_account_json),
        scope: SCOPE
      )
    end

    # Resolve the service-account JSON from (in order):
    #   1. FIREBASE_SERVICE_ACCOUNT_JSON  (raw JSON string — recommended on Render)
    #   2. FIREBASE_SERVICE_ACCOUNT_PATH  (path to a file on disk)
    #   3. Rails encrypted credentials    (firebase: { service_account_json: "..." })
    #   4. config/firebase_service_account.json  (local dev convenience)
    def service_account_json
      @service_account_json ||=
        ENV["FIREBASE_SERVICE_ACCOUNT_JSON"].presence ||
        (ENV["FIREBASE_SERVICE_ACCOUNT_PATH"].present? && File.exist?(ENV["FIREBASE_SERVICE_ACCOUNT_PATH"]) && File.read(ENV["FIREBASE_SERVICE_ACCOUNT_PATH"])) ||
        Rails.application.credentials.dig(:firebase, :service_account_json).presence ||
        (default_file_path.exist? && default_file_path.read) ||
        raise(ConfigurationError, "No Firebase service-account credentials found (set FIREBASE_SERVICE_ACCOUNT_JSON)")
    end

    def default_file_path
      @default_file_path ||= Rails.root.join("config", "firebase_service_account.json")
    end

    def credential_source
      if ENV["FIREBASE_SERVICE_ACCOUNT_JSON"].present? then "env:FIREBASE_SERVICE_ACCOUNT_JSON"
      elsif ENV["FIREBASE_SERVICE_ACCOUNT_PATH"].present? && File.exist?(ENV["FIREBASE_SERVICE_ACCOUNT_PATH"]) then "env:FIREBASE_SERVICE_ACCOUNT_PATH"
      elsif Rails.application.credentials.dig(:firebase, :service_account_json).present? then "rails_credentials"
      elsif default_file_path.exist? then "file:config/firebase_service_account.json"
      else "none"
      end
    end
  end
end
