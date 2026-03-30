module Notifications
  class Broadcaster
    def self.broadcast(notification)
      ActionCable.server.broadcast(
        "notifications_#{notification.recipient_account_id}",
        {
          type: "notification",
          event: "created",
          notification: NotificationBlueprint.render_as_hash(notification)
        }
      )
    end

    def self.broadcast_read(notification)
      ActionCable.server.broadcast(
        "notifications_#{notification.recipient_account_id}",
        {
          type: "notification",
          event: "read",
          notification: NotificationBlueprint.render_as_hash(notification)
        }
      )
    end

    def self.broadcast_all_read(account)
      ActionCable.server.broadcast(
        "notifications_#{account.id}",
        {
          type: "notification",
          event: "all_read",
          unread_count: account.unread_notifications_count
        }
      )
    end
  end
end
