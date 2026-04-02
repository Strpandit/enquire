class BusinessProfile < ApplicationRecord
  belongs_to :account

  has_many :reviews, dependent: :destroy
  has_many :business_profile_categories, dependent: :destroy
  has_many :categories, through: :business_profile_categories
  has_many :schedules, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :chat_conversations, dependent: :destroy
  has_many :chat_sessions, dependent: :destroy

  has_one_attached :gst_certificate

  enum :approval_status, { pending: 0, approved: 1, rejected: 2 }, default: :pending

  GST_REGEX = /\A[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]\z/
  PINCODE_REGEX = /\A\d{6}\z/
  PDF_CONTENT_TYPES = %w[application/pdf].freeze
  PDF_EXTENSIONS = %w[.pdf].freeze
  MAX_PDF_SIZE = 2.megabytes
  DANGEROUS_ATTACHMENT_EXTENSIONS = %w[
    .svg .js .mjs .html .htm .xhtml .xml .exe .bat .cmd .sh .php .jsp .aspx .cgi .pl
  ].freeze

  before_validation :normalize_gst_number
  before_validation :ensure_share_token, on: :create

  validates :business_name, presence: true, length: { minimum: 2, maximum: 120 }
  validates :business_address, presence: true, length: { maximum: 500 }
  validates :bio, length: { maximum: 160 }, allow_blank: true
  validates :about, length: { maximum: 1_000 }, allow_blank: true
  validates :chat_price, :call_price, :v_call_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :gst_number, format: { with: GST_REGEX, message: "must be a valid GST number" }, allow_blank: true, if: :gst_enabled?
  validates :gst_number, uniqueness: true, if: :gst_number?
  validates :pincode, format: { with: PINCODE_REGEX, message: "must be 6 digits" }, allow_blank: true
  validate :gst_number_presence_when_enabled
  validate :phone_must_exist_for_business_profile
  validate :category_limit
  validate :validate_gst_certificate_attachment

  def currently_available?(now: Time.current.in_time_zone(Time.zone))
    return false unless is_available?
    return true if schedules.where(availability_type: "always").exists?

    custom_schedules = if schedules.loaded?
      schedules.select(&:custom?)
    else
      schedules.where(availability_type: "custom")
    end

    return true if custom_schedules.blank?

    custom_schedules.any? do |schedule|
      schedule.day_of_week == now.wday && schedule.covers_time?(now)
    end
  end

  def gst_certificate_details
    attachment_details_for(gst_certificate)
  end

  def average_rating
    avg_rating || 0.0
  end

  def public_visible?
    approved?
  end

  def chat_price_cents
    (chat_price.to_d * 100).to_i
  end

  private

  def normalize_gst_number
    normalized_gst = gst_number.to_s.strip.upcase
    self.gst_number = normalized_gst.presence
  end

  def gst_number_presence_when_enabled
    return unless gst_enabled? && gst_number.blank?

    errors.add(:gst_number, "is required when GST is enabled")
  end

  def phone_must_exist_for_business_profile
    return if account&.phone.present?

    errors.add(:base, "Phone number must be present before creating a business profile")
  end

  def category_limit
    return unless categories.size > 15

    errors.add(:categories, "can have a maximum of 15 categories")
  end

  def ensure_share_token
    self.share_token ||= SecureRandom.urlsafe_base64(10)
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

  def validate_gst_certificate_attachment
    return unless gst_certificate.attached?

    blob = gst_certificate.blob
    return errors.add(:gst_certificate, "upload is invalid") if blob.blank?

    if dangerous_attachment_filename?(blob.filename.to_s)
      errors.add(:gst_certificate, "contains a forbidden file extension")
      return
    end

    if suspicious_double_extension?(blob.filename.to_s, allowed_extensions: PDF_EXTENSIONS)
      errors.add(:gst_certificate, "filename contains a suspicious double extension")
      return
    end

    unless PDF_CONTENT_TYPES.include?(blob.content_type.to_s.downcase)
      errors.add(:gst_certificate, "must be a PDF document")
    end

    unless PDF_EXTENSIONS.include?(File.extname(blob.filename.to_s).downcase)
      errors.add(:gst_certificate, "must use .pdf format")
    end

    if blob.byte_size > MAX_PDF_SIZE
      errors.add(:gst_certificate, "must be 2 MB or smaller")
    end
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
end
