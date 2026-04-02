module Notifications
  class Broadcaster
    def self.broadcast(notification, event = "created")
      ActionCable.server.broadcast(
        "notifications_#{notification.recipient_account_id}",
        {
          type: "notification",
          event: event,
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

    def self.channel_for(account_id)
      "notifications_#{account_id}"
    end
    
  end
end
