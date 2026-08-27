class ChatConversationChannel < ApplicationCable::Channel
  def subscribed
    conversation = ChatConversation.find(params[:conversation_id])
    Chat::ConversationAccess.ensure_participant!(conversation: conversation, account: current_account)

    stream_from "chat_conversation_#{conversation.id}"
  rescue ActiveRecord::RecordNotFound, Chat::ConversationAccess::Error
    reject
  end

  def receive(data)
    conversation = ChatConversation.find(data.fetch("conversation_id"))
    Chat::ConversationAccess.ensure_participant!(conversation: conversation, account: current_account)

    case data["action"]
    when "message"
      Chat::MessageService.new(conversation: conversation, sender: current_account).create!(
        content: data.fetch("content", ""),
        attachment: nil
      )
    when "heartbeat"
      session = conversation.chat_sessions.find(data.fetch("chat_session_id"))
      Chat::BillingService.new(session).sync!
    when "mark_read"
      Chat::ReadReceiptService.new(conversation: conversation, reader: current_account).mark_all_read!
    when "typing"
      recipient = conversation.other_participant_for(current_account)
      ActionCable.server.broadcast("chat_conversation_#{conversation.id}", {
        type: "typing",
        sender_account_id: current_account.id,
        recipient_account_id: recipient.id,
        expires_at: 3.seconds.from_now.iso8601
      })
    end
  rescue ActiveRecord::RecordNotFound, Chat::ConversationAccess::Error,
         Chat::MessageService::Error, Chat::BillingService::Error => error
    transmit(type: "error", errors: [ error.message ])
  end
end
