class Account < ApplicationRecord
  has_secure_password
  acts_as_paranoid

  OTP_EXPIRY_WINDOW = 5.minutes
  PASSWORD_RESET_TOKEN_WINDOW = 15.minutes

  has_one :business_profile, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :favorite_business_profiles, through: :favorites, source: :business_profile
  has_many :received_notifications, class_name: "Notification", foreign_key: :recipient_account_id, dependent: :destroy
  has_many :sent_notifications, class_name: "Notification", foreign_key: :actor_account_id, dependent: :nullify
  has_many :device_installations, dependent: :destroy
  has_many :customer_chat_conversations, class_name: "ChatConversation", foreign_key: :customer_account_id, dependent: :destroy
  has_many :sent_chat_messages, class_name: "ChatMessage", foreign_key: :sender_account_id, dependent: :nullify
  has_many :wallet_transactions, dependent: :destroy
  has_many :customer_chat_sessions, class_name: "ChatSession", foreign_key: :customer_account_id, dependent: :nullify

  has_one_attached :profile_pic
  has_one_attached :pan_card
  has_one_attached :aadhaar_card
  has_one_attached :passport_photo

  EMAIL_REGEX = URI::MailTo::EMAIL_REGEXP
  PHONE_REGEX = /\A[6-9]\d{9}\z/
  USERNAME_REGEX = /\A[a-z0-9_]+\z/i
  PINCODE_REGEX = /\A\d{6}\z/
  JPEG_CONTENT_TYPES = %w[image/jpeg image/jpg].freeze
  JPEG_EXTENSIONS = %w[.jpg .jpeg].freeze
  MAX_IMAGE_SIZE = 1.megabyte
  DANGEROUS_ATTACHMENT_EXTENSIONS = %w[
    .svg .js .mjs .html .htm .xhtml .xml .exe .bat .cmd .sh .php .jsp .aspx .cgi .pl
  ].freeze

  enum :verification_status, {
    unsubmitted: 0,
    pending: 1,
    approved: 2,
    rejected: 3
  }, default: :unsubmitted

  before_validation :normalize_email
  before_validation :ensure_uid
  before_validation :normalize_username
  before_validation :normalize_languages

  validates :uid, presence: true, uniqueness: true
  validates :full_name, presence: true, length: { minimum: 3, maximum: 80 }
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: EMAIL_REGEX }
  validates :phone, uniqueness: true, format: { with: PHONE_REGEX, message: "must be a valid 10-digit Indian mobile number" }, allow_blank: true
  validates :username, uniqueness: { case_sensitive: false }, format: { with: USERNAME_REGEX, message: "can only contain letters, numbers, and underscores" }, length: { minimum: 3, maximum: 30 }, if: :username?
  validates :password, length: { minimum: 8 }, if: :password_required?
  validates :pincode, format: { with: PINCODE_REGEX, message: "must be 6 digits" }, allow_blank: true
  validates :wallet_balance_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validate :phone_required_for_verification_submission
  validate :verification_documents_complete_for_submission
  validate :validate_profile_pic_attachment
  validate :validate_pan_card_attachment
  validate :validate_aadhaar_card_attachment
  validate :validate_passport_photo_attachment

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

  def wallet_balance
    wallet_balance_cents.to_i / 100.0
  end

  def business_account?
    business_profile.present? && is_business?
  end

  def online?
    Rails.cache.read("account_presence:#{id}") == true
  end

  def unread_notifications_count
    received_notifications.unread.count
  end

  def profile_pic_details
    attachment_details_for(profile_pic)
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def ensure_uid
    self.uid ||= loop do
      candidate = SecureRandom.alphanumeric(6).downcase
      break candidate unless self.class.exists?(uid: candidate)
    end
  end

  def normalize_username
    self.username = username.to_s.strip.downcase.presence
  end

  def normalize_languages
    self.languages = languages
  end

  def password_required?
    new_record? || password.present?
  end

  def phone_required_for_verification_submission
    return unless verification_status == "pending" && phone.blank?

    errors.add(:phone, "must be present before submitting verification")
  end

  def verification_documents_complete_for_submission
    return unless verification_status == "pending"

    errors.add(:pan_card, "must be attached") unless pan_card.attached?
    errors.add(:aadhaar_card, "must be attached") unless aadhaar_card.attached?
    errors.add(:passport_photo, "must be attached") unless passport_photo.attached?
  end

  def validate_profile_pic_attachment
    validate_jpeg_attachment(:profile_pic, label: "profile picture")
  end

  def validate_pan_card_attachment
    validate_jpeg_attachment(:pan_card, label: "PAN card")
  end

  def validate_aadhaar_card_attachment
    validate_jpeg_attachment(:aadhaar_card, label: "Aadhaar card")
  end

  def validate_passport_photo_attachment
    validate_jpeg_attachment(:passport_photo, label: "passport photo")
  end

  def validate_jpeg_attachment(name, label:)
    attachment = public_send(name)
    return unless attachment.attached?

    blob = attachment.blob
    return errors.add(name, "#{label} upload is invalid") if blob.blank?

    if dangerous_attachment_filename?(blob.filename.to_s)
      errors.add(name, "#{label} contains a forbidden file extension")
      return
    end

    if suspicious_double_extension?(blob.filename.to_s, allowed_extensions: JPEG_EXTENSIONS)
      errors.add(name, "#{label} filename contains a suspicious double extension")
      return
    end

    unless JPEG_CONTENT_TYPES.include?(blob.content_type.to_s.downcase)
      errors.add(name, "#{label} must be a JPG or JPEG image")
    end

    unless JPEG_EXTENSIONS.include?(File.extname(blob.filename.to_s).downcase)
      errors.add(name, "#{label} must use .jpg or .jpeg format")
    end

    if blob.byte_size > MAX_IMAGE_SIZE
      errors.add(name, "#{label} must be 1 MB or smaller")
    end
  end

  def attachment_details_for(attachment)
    return nil unless attachment.attached?

    blob = attachment.blob
    return nil if blob.blank?

    {
      url: Rails.application.routes.url_helpers.url_for(attachment),
      filename: blob.filename.to_s,
      content_type: blob.content_type,
      byte_size: blob.byte_size
    }
  end

  def dangerous_attachment_filename?(filename)
    extensions = filename_extensions(filename)
    extensions.any? { |extension| DANGEROUS_ATTACHMENT_EXTENSIONS.include?(extension) }
  end

  def suspicious_double_extension?(filename, allowed_extensions:)
    extensions = filename_extensions(filename)
    return false if extensions.empty?

    extensions[0...-1].any? do |extension|
      DANGEROUS_ATTACHMENT_EXTENSIONS.include?(extension) || !allowed_extensions.include?(extension)
    end
  end

  def filename_extensions(filename)
    name = File.basename(filename.to_s.downcase)
    return [] if name.blank?

    segments = name.split(".")
    return [] if segments.length <= 1

    segments.drop(1).map { |segment| ".#{segment}" }
  end

  def digest_token(raw_token)
    Digest::SHA256.hexdigest(raw_token)
  end
end
