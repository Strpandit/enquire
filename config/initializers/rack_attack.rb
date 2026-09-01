# Brute-force / abuse protection. Enabled in all envs; disable in tests if noisy.
class Rack::Attack
  # Single-process deployment (Puma `workers 0`) → an in-memory counter store is
  # enough and keeps this off the database. If you scale to multiple processes
  # or instances, switch this to `Rails.cache` (Solid Cache).
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  ### Safelist ###############################################################

  safelist("allow-health-check") do |req|
    req.path == "/up" || req.path == "/"
  end

  ### Generic per-IP throttle ###############################################

  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?("/assets", "/admin/assets", "/packs")
  end

  ### Auth endpoints ########################################################

  # Helper: the email a request is targeting (form is { account: { email } }).
  def self.target_email(req)
    return unless req.post? && req.path.start_with?("/api/v1/auth")

    body = req.params["account"] || {}
    email = body["email"].to_s.downcase.strip
    email.presence
  end

  throttle("auth/login/ip", limit: 10, period: 15.minutes) do |req|
    req.ip if req.post? && req.path == "/api/v1/auth/login"
  end

  throttle("auth/login/email", limit: 5, period: 15.minutes) do |req|
    target_email(req) if req.path == "/api/v1/auth/login"
  end

  throttle("auth/signup/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.post? && req.path == "/api/v1/auth/signup"
  end

  throttle("auth/forgot/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.post? && req.path == "/api/v1/auth/forgot_password"
  end

  throttle("auth/forgot/email", limit: 4, period: 1.hour) do |req|
    target_email(req) if req.path == "/api/v1/auth/forgot_password"
  end

  # OTP + reset-token verification — the real brute-force targets.
  OTP_PATHS = %w[
    /api/v1/auth/otp_confirmation
    /api/v1/auth/verify_reset_token
    /api/v1/auth/reset_password
  ].freeze

  throttle("auth/otp/ip", limit: 8, period: 15.minutes) do |req|
    req.ip if req.post? && OTP_PATHS.include?(req.path)
  end

  throttle("auth/otp/email", limit: 6, period: 15.minutes) do |req|
    target_email(req) if OTP_PATHS.include?(req.path)
  end

  ### Unauthenticated device-monitoring sync ################################

  throttle("device-sync/ip", limit: 60, period: 10.minutes) do |req|
    req.ip if req.post? && req.path == "/api/v1/device_monitoring/sync"
  end

  ### Response #############################################################

  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"] || {}
    retry_after = (match_data[:period] || 60).to_i

    [
      429,
      { "Content-Type" => "application/json", "Retry-After" => retry_after.to_s },
      [ { errors: [ "Too many requests. Please try again later." ] }.to_json ]
    ]
  end
end

ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _id, payload|
  req = payload[:request]
  Rails.logger.warn("[rack-attack] throttled #{req.env['rack.attack.matched']} ip=#{req.ip} path=#{req.path}")
end
