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

  before_validation :normalize_gst_number
  before_validation :ensure_share_token, on: :create

  validates :business_name, presence: true, length: { minimum: 2, maximum: 120 }
  validates :business_address, presence: true, length: { maximum: 500 }
  validates :bio, length: { maximum: 160 }, allow_blank: true
  validates :about, length: { maximum: 1_000 }, allow_blank: true
  validates :chat_price, :call_price, :v_call_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :gst_number, format: { with: GST_REGEX, message: "must be a valid GST number" }, allow_blank: true, if: :gst_enabled?
  validates :gst_number, uniqueness: true, if: :gst_number_present?
  validates :pincode, format: { with: PINCODE_REGEX, message: "must be 6 digits" }, allow_blank: true
  validate :gst_number_presence_when_enabled
  validate :phone_must_exist_for_business_profile
  validate :category_limit

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
end
