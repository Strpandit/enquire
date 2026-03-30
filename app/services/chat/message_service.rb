module Chat
  class MessageService
    class Error < StandardError; end

    def initialize(conversation:, sender:)
      @conversation = conversation
      @sender = sender
    end

    def create!(content:)
      Chat::ConversationAccess.ensure_participant!(conversation: conversation, account: sender)
      chat_session = conversation.active_or_requested_session
      raise Error, "No active chat session found" unless chat_session&.active?

      Chat::BillingService.new(chat_session).sync!
      chat_session.reload
      raise Error, "Chat session is no longer active" unless chat_session.active?

      message = nil
      ActiveRecord::Base.transaction do
        message = conversation.chat_messages.create!(
          chat_session: chat_session,
          sender_account: sender,
          content: content,
          sent_at: Time.current
        )

        conversation.update!(
          last_message_at: message.sent_at,
          last_message_preview: message.content.truncate(120)
        )
      end

      Chat::Broadcaster.broadcast_to_conversation(conversation, {
        type: "chat_message",
        event: "message_created",
        message: ChatMessageBlueprint.render_as_hash(message)
      })

      Notifications::Creator.call(
        recipient: recipient_account,
        actor: sender,
        notifiable: conversation,
        notification_type: "chat_message_received",
        title: "New message",
        body: "#{sender.full_name}: #{message.content.truncate(80)}",
        payload: { chat_conversation_id: conversation.id, chat_session_id: chat_session.id, last_chat_message_id: message.id },
        push: !recipient_account.online?,
        collapse: true
      )
      message
    end

    private

    attr_reader :conversation, :sender

    def recipient_account
      conversation.other_participant_for(sender)
    end
  end
end
