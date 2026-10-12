class ChatConversationChannel < ApplicationCable::Channel
  def subscribed
    conversation = ChatConversation.find(params[:conversation_id])
    Chat::ConversationAccess.ensure_participant!(conversation: conversation, account: current_account)

    stream_from "chat_conversation_#{conversation.id}"
  rescue ActiveRecord::RecordNotFound, Chat::ConversationAccess::Error
    reject
  end

  # ActionCable dispatches any client message that carries an "action" key to a
  # public channel method of that name (and only falls back to #receive when
  # there is no action). Each action must therefore be a real method, otherwise
  # it is dropped with "Unable to process ...".
  def message(data)
    dispatch_chat_action("message", data)
  end

  def heartbeat(data)
    dispatch_chat_action("heartbeat", data)
  end

  def mark_read(data)
    dispatch_chat_action("mark_read", data)
  end

  def typing(data)
    dispatch_chat_action("typing", data)
  end

  def receive(data)
    dispatch_chat_action(data["action"], data)
  end

  private

  def dispatch_chat_action(action, data)
    conversation = ChatConversation.find(data.fetch("conversation_id"))
    Chat::ConversationAccess.ensure_participant!(conversation: conversation, account: current_account)

    case action.to_s
    when "message"
      Chat::MessageService.new(conversation: conversation, sender: current_account).create!(
        content: data.fetch("content", ""),
        attachments: []
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
  rescue ActiveRecord::RecordNotFound, KeyError, Chat::ConversationAccess::Error,
         Chat::MessageService::Error, Chat::BillingService::Error => error
    transmit(type: "error", errors: [ error.message ])
  end
end
