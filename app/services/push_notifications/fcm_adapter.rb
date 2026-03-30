require "googleauth"
require "net/http"

module PushNotifications
  class FcmAdapter
    SCOPE = "https://www.googleapis.com/auth/firebase.messaging".freeze

    def deliver(notification:, installation:)
      response = http_client.request(build_request(access_token, installation.device_token, notification))
      raise "FCM push failed with status #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      true
    end

    private

    def build_request(token, device_token, notification)
      request = Net::HTTP::Post.new(endpoint)
      request["Authorization"] = "Bearer #{token}"
      request["Content-Type"] = "application/json; charset=UTF-8"
      request.body = {
        message: {
          token: device_token,
          notification: {
            title: notification.title,
            body: notification.body
          },
          data: notification_payload(notification)
        }
      }.to_json
      request
    end

    def notification_payload(notification)
      (notification.payload || {}).transform_values(&:to_s).merge(
        "notification_id" => notification.id.to_s,
        "notification_type" => notification.notification_type.to_s
      )
    end

    def endpoint
      URI("https://fcm.googleapis.com/v1/projects/#{ENV.fetch('FIREBASE_PROJECT_ID')}/messages:send")
    end

    def http_client
      @http_client ||= Net::HTTP.start(endpoint.host, endpoint.port, use_ssl: true)
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
      ENV["FIREBASE_SERVICE_ACCOUNT_JSON"].presence || File.read(ENV.fetch("FIREBASE_SERVICE_ACCOUNT_PATH"))
    end
  end
end
