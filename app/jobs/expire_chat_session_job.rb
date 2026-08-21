class ExpireChatSessionJob < ApplicationJob
  queue_as :default

  def perform(chat_session_id)
    chat_session = ChatSession.find_by(id: chat_session_id)
    return if chat_session.blank? || !chat_session.requested?
    return if chat_session.requested_at > ChatSession::REQUEST_TIMEOUT.ago

    chat_session.update!(status: :expired, ended_at: Time.current, end_reason: "request_timeout")
    Chat::Broadcaster.broadcast_to_conversation(chat_session.chat_conversation, {
      type: "chat_session",
      event: "session_expired",
      session: ChatSessionBlueprint.render_as_hash(chat_session)
    })
    notify_expired(chat_session)
  end

  private

  def notify_expired(chat_session)
    payload = { chat_conversation_id: chat_session.chat_conversation_id, chat_session_id: chat_session.id }

    # Notify customer that their request expired
    Notifications::Creator.call(
      recipient: chat_session.customer_account,
      actor: chat_session.business_profile.account,
      notifiable: chat_session,
      notification_type: "chat_request_expired",
      title: "Chat request expired",
      body: "Your chat request to #{chat_session.business_profile.business_name} expired because it was not accepted in time.",
      payload: payload
    )

    # Notify expert that they missed a chat request
    Notifications::Creator.call(
      recipient: chat_session.business_profile.account,
      actor: chat_session.customer_account,
      notifiable: chat_session,
      notification_type: "chat_request_missed",
      title: "Missed chat request",
      body: "#{chat_session.customer_account.full_name} sent a chat request that expired without a response.",
      payload: payload
    )
  end
end
