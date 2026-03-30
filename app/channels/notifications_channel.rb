class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "notifications_#{current_account.id}"
  end
end
