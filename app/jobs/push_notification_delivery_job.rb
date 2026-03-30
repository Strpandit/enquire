class PushNotificationDeliveryJob < ApplicationJob
  queue_as :default

  def perform(notification_id)
    notification = Notification.find_by(id: notification_id)
    return if notification.blank?

    PushNotifications::Dispatcher.new(notification).deliver!
  end
end
