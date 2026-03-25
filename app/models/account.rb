class Account < ApplicationRecord
  has_secure_password
  acts_as_paranoid

  OTP_EXPIRY_WINDOW = 5.minutes
  PASSWORD_RESET_TOKEN_WINDOW = 15.minutes

  has_one :business_profile, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :favorite_business_profiles, through: :favorites, source: :business_profile

  has_one_attached :profile_pic
  has_one_attached :pan_card
  has_one_attached :aadhaar_card
  has_one_attached :passport_photo

  EMAIL_REGEX = URI::MailTo::EMAIL_REGEXP
  PHONE_REGEX = /\A[6-9]\d{9}\z/
  USERNAME_REGEX = /\A[a-z0-9_]+\z/i
  PINCODE_REGEX = /\A\d{6}\z/

  enum :verification_status, {
    unsubmitted: 0,
    pending: 1,
    approved: 2,
    rejected: 3
  }, default: :unsubmitted

  before_validation :normalize_email
  before_validation :normalize_username
  before_validation :normalize_languages

  validates :full_name, presence: true, length: { minimum: 3, maximum: 80 }
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: EMAIL_REGEX }
  validates :phone, uniqueness: true, format: { with: PHONE_REGEX, message: "must be a valid 10-digit Indian mobile number" }, allow_blank: true
  validates :username, uniqueness: { case_sensitive: false }, format: { with: USERNAME_REGEX, message: "can only contain letters, numbers, and underscores" }, length: { minimum: 3, maximum: 30 }, allow_blank: true
  validates :password, length: { minimum: 8 }, if: :password_required?
  validates :pincode, format: { with: PINCODE_REGEX, message: "must be 6 digits" }, allow_blank: true
  validate :phone_required_for_verification_submission
  validate :verification_documents_complete_for_submission

  def languages
    JSON.parse(self[:languages].presence || "[]")
  rescue JSON::ParserError
    []
  end

  def languages=(value)
    normalized = Array(value).flatten.compact.map(&:to_s).map(&:strip).reject(&:blank?).uniq
    self[:languages] = normalized.to_json
  end

  def generate_password_reset_otp!
    update!(
      otp_pin: rand(100_000..999_999).to_s,
      otp_sent_at: Time.current,
      reset_password_token_digest: nil,
      reset_password_sent_at: nil
    )
  end

  def password_reset_otp_valid?(otp)
    otp_pin.present? &&
      otp_sent_at.present? &&
      otp_sent_at >= OTP_EXPIRY_WINDOW.ago &&
      ActiveSupport::SecurityUtils.secure_compare(otp_pin, otp.to_s)
  end

  def generate_reset_password_token!
    raw_token = SecureRandom.hex(24)

    update!(
      reset_password_token_digest: digest_token(raw_token),
      reset_password_sent_at: Time.current,
      otp_pin: nil,
      otp_sent_at: nil
    )

    raw_token
  end

  def valid_reset_password_token?(raw_token)
    return false if raw_token.blank? || reset_password_token_digest.blank? || reset_password_sent_at.blank?
    return false if reset_password_sent_at < PASSWORD_RESET_TOKEN_WINDOW.ago

    ActiveSupport::SecurityUtils.secure_compare(reset_password_token_digest, digest_token(raw_token))
  end

  def clear_password_reset_credentials!
    update!(
      otp_pin: nil,
      otp_sent_at: nil,
      reset_password_token_digest: nil,
      reset_password_sent_at: nil
    )
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def normalize_username
    self.username = username.to_s.strip.downcase
  end

  def normalize_languages
    self.languages = languages
  end

  def password_required?
    password.present? || new_record?
  end

  def phone_required_for_verification_submission
    return unless pending?
    return if phone.present?

    errors.add(:phone, "is required before requesting verification")
  end

  def verification_documents_complete_for_submission
    return unless pending?
    return if pan_card.attached? && aadhaar_card.attached? && passport_photo.attached?

    errors.add(:base, "PAN card, Aadhaar card, and passport size photo are required for verification")
  end

  def digest_token(token)
    Digest::SHA256.hexdigest(token)
  end
end
