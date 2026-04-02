class Notification < ApplicationRecord
  belongs_to :recipient_account, class_name: "Account"
  belongs_to :actor_account, class_name: "Account", optional: true
  belongs_to :notifiable, polymorphic: true, optional: true

  validates :notification_type, :title, :body, presence: true

  scope :recent_first, -> { order(updated_at: :desc, created_at: :desc) }
  scope :unread, -> { where(read_at: nil) }
  scope :for_inbox, -> { includes(:actor_account) }

  after_create_commit :handle_create
  after_update_commit :handle_update

  def read?
    read_at.present?
  end

  def mark_as_read!(timestamp: Time.current)
    return false if read?

    update!(read_at: timestamp)
  end

  private

  def handle_create
    broadcast_notification("created")
    enqueue_push_notification
  end

  def handle_update
    if saved_change_to_read_at?
      broadcast_notification("read")
    else
      broadcast_notification("updated")
    end
  end

  def broadcast_notification(event)
    Notifications::Broadcaster.broadcast(self, event)
  end

  def enqueue_push_notification
    return unless previous_changes.key?("id") || previous_changes.key?("push_sent_at")

    PushNotificationDeliveryJob.perform_later(id)
  end
end
