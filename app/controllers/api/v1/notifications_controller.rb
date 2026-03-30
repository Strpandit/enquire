module Api
  module V1
    class NotificationsController < BaseController
      def index
        notifications = current_account.received_notifications.for_inbox.recent_first.page(params[:page]).per(per_page)
        render json: {
          notifications: NotificationBlueprint.render_as_hash(notifications),
          meta: pagination_meta(notifications),
          unread_count: current_account.unread_notifications_count
        }, status: :ok
      end

      def unread_count
        render json: { unread_count: current_account.unread_notifications_count }, status: :ok
      end

      def mark_read
        notification = current_account.received_notifications.find(params[:id])
        notification.mark_as_read!
        Notifications::Broadcaster.broadcast_read(notification)

        render json: {
          message: "Notification marked as read",
          notification: NotificationBlueprint.render_as_hash(notification),
          unread_count: current_account.unread_notifications_count
        }, status: :ok
      end

      def mark_all_read
        unread_scope = current_account.received_notifications.unread
        now = Time.current
        updated_count = unread_scope.update_all(read_at: now)
        Notifications::Broadcaster.broadcast_all_read(current_account) if updated_count.positive?

        render json: {
          message: "All notifications marked as read",
          unread_count: 0
        }, status: :ok
      end
    end
  end
end
