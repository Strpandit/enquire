class Notification < ApplicationRecord
  belongs_to :recipient_account, class_name: "Account"
  belongs_to :actor_account, class_name: "Account", optional: true
  belongs_to :notifiable, polymorphic: true, optional: true

  validates :notification_type, :title, :body, presence: true

  scope :recent_first, -> { order(updated_at: :desc, created_at: :desc) }
  scope :unread, -> { where(read_at: nil) }
  scope :for_inbox, -> { includes(:actor_account) }

  def read?
    read_at.present?
  end

  def mark_as_read!(timestamp: Time.current)
    return false if read?

    update!(read_at: timestamp)
  end
end
