module Notifications
  class Creator
    def self.call(...)
      new(...).call
    end

    def initialize(recipient:, notification_type:, title:, body:, actor: nil, notifiable: nil, payload: {}, push: true, collapse: false)
      @recipient = recipient
      @notification_type = notification_type
      @title = title
      @body = body
      @actor = actor
      @notifiable = notifiable
      @payload = payload || {}
      @push = push
      @collapse = collapse
    end

    def call
      return if recipient.blank?

      collapse ? find_or_refresh_collapsed_notification! : build_notification!
    end

    private

    attr_reader :recipient, :notification_type, :title, :body, :actor, :notifiable, :payload, :push, :collapse

    def build_notification!
      notification = Notification.create!(notification_attributes)
      dispatch_push!(notification)
      notification
    end

    def find_or_refresh_collapsed_notification!
      Notification.transaction do
        notification = Notification.unread.lock.find_by(
          recipient_account: recipient,
          actor_account: actor,
          notification_type: notification_type,
          notifiable: notifiable
        )

        if notification.blank?
          notification = Notification.create!(notification_attributes)
        else
          notification.update!(
            title: title,
            body: body,
            payload: payload,
            push_sent_at: nil
          )
        end

        dispatch_push!(notification)
        notification
      end
    end

    # Enqueue FCM push delivery as a background job so it doesn't block the
    # request cycle. The job calls PushNotifications::Dispatcher which handles
    # FCM token lookup and delivery.
    def dispatch_push!(notification)
      return unless push
      return if notification.blank?

      PushNotificationDeliveryJob.perform_later(notification.id)
    end

    def notification_attributes
      {
        recipient_account: recipient,
        actor_account: actor,
        notifiable: notifiable,
        notification_type: notification_type,
        title: title,
        body: body,
        payload: payload
      }
    end
  end
end
