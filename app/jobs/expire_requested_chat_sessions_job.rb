class ExpireRequestedChatSessionsJob < ApplicationJob
  queue_as :default

  def perform
    ChatSession.where(status: :requested).where("requested_at <= ?", ChatSession::REQUEST_TIMEOUT.ago).find_each do |chat_session|
      chat_session.update!(status: :expired, ended_at: Time.current, end_reason: "request_timeout")
      Chat::Broadcaster.broadcast_to_conversation(chat_session.chat_conversation, {
        type: "chat_session",
        event: "session_expired",
        session: ChatSessionBlueprint.render_as_hash(chat_session)
      })
      Notifications::Creator.call(
        recipient: chat_session.customer_account,
        actor: chat_session.business_profile.account,
        notifiable: chat_session,
        notification_type: "chat_request_expired",
        title: "Chat request expired",
        body: "Your chat request expired because it was not accepted in time.",
        payload: { chat_conversation_id: chat_session.chat_conversation_id, chat_session_id: chat_session.id }
      )
    end
  end
end
