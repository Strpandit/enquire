class JsonWebToken
  SECRET_KEY = Rails.application.credentials.secret_key_base || ENV["SECRET_KEY_BASE"] || "development_secret_key"
  EXPIRATION_WINDOW = 30.days

  def self.encode(payload, exp = EXPIRATION_WINDOW.from_now)
    JWT.encode(payload.merge(exp: exp.to_i), SECRET_KEY)
  end

  def self.decode(token)
    JWT.decode(token, SECRET_KEY, true, algorithm: "HS256").first
  end
end
