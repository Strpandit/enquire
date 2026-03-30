class ChatMessage < ApplicationRecord
  belongs_to :chat_conversation
  belongs_to :chat_session, optional: true
  belongs_to :sender_account, class_name: "Account"

  enum :message_type, { text: 0, system: 1 }, default: :text

  validates :content, presence: true, length: { maximum: 2_000 }
  validates :sent_at, presence: true

  scope :unread, -> { where(read_at: nil) }
end
