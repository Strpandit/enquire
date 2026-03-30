class NotificationBlueprint < Blueprinter::Base
  identifier :id

  fields :notification_type, :title, :body, :read_at, :push_sent_at, :payload, :created_at

  field :actor do |notification|
    next unless notification.actor_account

    {
      id: notification.actor_account.id,
      uid: notification.actor_account.uid,
      full_name: notification.actor_account.full_name,
      username: notification.actor_account.username
    }
  end

  field :notifiable do |notification|
    next unless notification.notifiable

    {
      id: notification.notifiable_id,
      type: notification.notifiable_type
    }
  end
end
