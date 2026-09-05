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

    def service_account_json
      @service_account_json ||= normalize_service_account_json(resolve_raw_service_account_json)
    end

    def resolve_raw_service_account_json
      if ENV["FIREBASE_SERVICE_ACCOUNT_JSON"].present?
        ENV["FIREBASE_SERVICE_ACCOUNT_JSON"]
      elsif ENV["FIREBASE_SERVICE_ACCOUNT_PATH"].present? && File.exist?(ENV["FIREBASE_SERVICE_ACCOUNT_PATH"])
        File.read(ENV["FIREBASE_SERVICE_ACCOUNT_PATH"])
      elsif render_secret_file_path.exist?
        render_secret_file_path.read
      elsif Rails.application.credentials.dig(:firebase, :service_account_json).present?
        Rails.application.credentials.dig(:firebase, :service_account_json)
      elsif default_file_path.exist?
        default_file_path.read
      else
        raise ConfigurationError, "No Firebase service-account credentials found (set FIREBASE_SERVICE_ACCOUNT_JSON or add secret file)"
      end
    end

    def normalize_service_account_json(raw)
      cleaned = raw.to_s.strip
      if (cleaned.start_with?("'") && cleaned.end_with?("'")) || (cleaned.start_with?('"') && cleaned.end_with?('"') && cleaned.count('"') > 2 && !cleaned[1..-2].include?('"'))
        cleaned = cleaned[1..-2].strip
      end

      parsed =
        begin
          JSON.parse(cleaned)
        rescue JSON::ParserError
          begin
            JSON.parse(cleaned.gsub('\r\n', "\n").gsub('\n', "\n"))
          rescue JSON::ParserError
            nil
          end
        end

      if parsed.is_a?(Hash)
        if parsed["private_key"].is_a?(String)
          if parsed["private_key"].include?('\n') && !parsed["private_key"].include?("\n")
            parsed["private_key"] = parsed["private_key"].gsub('\n', "\n")
          end
        end
        return parsed.to_json
      end

      cleaned
    end

    def default_file_path
      @default_file_path ||= Rails.root.join("config", "firebase_service_account.json")
    end

    def render_secret_file_path
      @render_secret_file_path ||= Pathname.new("/etc/secrets/firebase_service_account.json")
    end

    def credential_source
      if ENV["FIREBASE_SERVICE_ACCOUNT_JSON"].present? then "env:FIREBASE_SERVICE_ACCOUNT_JSON"
      elsif ENV["FIREBASE_SERVICE_ACCOUNT_PATH"].present? && File.exist?(ENV["FIREBASE_SERVICE_ACCOUNT_PATH"]) then "env:FIREBASE_SERVICE_ACCOUNT_PATH"
      elsif render_secret_file_path.exist? then "secret_file:/etc/secrets/firebase_service_account.json"
      elsif Rails.application.credentials.dig(:firebase, :service_account_json).present? then "rails_credentials"
      elsif default_file_path.exist? then "file:config/firebase_service_account.json"
      else "none"
      end
    end
  end
end
