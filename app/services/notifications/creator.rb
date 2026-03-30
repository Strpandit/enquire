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

      notification = collapse ? find_or_refresh_collapsed_notification! : build_notification!

      Notifications::Broadcaster.broadcast(notification)
      PushNotificationDeliveryJob.perform_later(notification.id) if push
      notification
    end

    private

    attr_reader :recipient, :notification_type, :title, :body, :actor, :notifiable, :payload, :push, :collapse

    def build_notification!
      Notification.create!(notification_attributes)
    end

    def find_or_refresh_collapsed_notification!
      notification = Notification.unread.find_by(
        recipient_account: recipient,
        actor_account: actor,
        notification_type: notification_type,
        notifiable: notifiable
      )

      return build_notification! if notification.blank?

      notification.update!(
        title: title,
        body: body,
        payload: payload,
        push_sent_at: nil
      )
      notification
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
