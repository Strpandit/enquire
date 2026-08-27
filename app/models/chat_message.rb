class ChatMessage < ApplicationRecord
  belongs_to :chat_conversation
  belongs_to :chat_session, optional: true
  belongs_to :sender_account, class_name: "Account"

  has_many_attached :attachments

  ALLOWED_ATTACHMENT_CONTENT_TYPES = %w[
    image/jpeg image/jpg image/png image/webp
    application/pdf
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.ms-excel
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    application/vnd.ms-powerpoint
    application/vnd.openxmlformats-officedocument.presentationml.presentation
    text/plain
  ].freeze

  IMAGE_CONTENT_TYPES = %w[image/jpeg image/jpg image/png image/webp].freeze

  MAX_ATTACHMENT_SIZE      = 15.megabytes
  MAX_ATTACHMENTS_PER_MSG  = 10

  enum :message_type, { text: 0, system: 1, image: 2, document: 3, media: 4 }, default: :text

  validates :content, presence: true, length: { maximum: 2_000 }, if: -> { text? || system? }
  validates :content, length: { maximum: 500 }, allow_blank: true, if: -> { image? || document? || media? }
  validates :sent_at, presence: true
  validate :validate_attachments, if: -> { attachments.any? }

  scope :unread,     -> { where(read_at: nil) }
  scope :before_id,  ->(id) { where("chat_messages.id < ?", id) }

  private

  def validate_attachments
    if attachments.length > MAX_ATTACHMENTS_PER_MSG
      errors.add(:attachments, "cannot exceed #{MAX_ATTACHMENTS_PER_MSG} files per message")
      return
    end

    attachments.each do |attachment|
      blob = attachment.blob
      next unless blob

      unless ALLOWED_ATTACHMENT_CONTENT_TYPES.include?(blob.content_type.to_s.downcase)
        errors.add(:attachments, "#{blob.filename} — type not allowed. Only images and documents are permitted.")
      end

      if blob.byte_size > MAX_ATTACHMENT_SIZE
        errors.add(:attachments, "#{blob.filename} is too large. Maximum size per file is 15 MB.")
      end
    end
  end
end
