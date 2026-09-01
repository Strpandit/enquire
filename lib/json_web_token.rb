class JsonWebToken
  EXPIRATION_WINDOW = 30.days

  def self.secret_key
    @secret_key ||= Rails.application.secret_key_base
  end

  def self.encode(payload, exp = EXPIRATION_WINDOW.from_now)
    JWT.encode(payload.merge(exp: exp.to_i), secret_key)
  end

  def self.encode_for(account, exp = EXPIRATION_WINDOW.from_now)
    encode({ account_id: account.id, pwd: account.password_token_fingerprint }, exp)
  end

  def self.decode(token)
    JWT.decode(token, secret_key, true, algorithm: "HS256").first
  end
end
