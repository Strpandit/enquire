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

      filter_result = Chat::SecurityFilter.analyze(content)
      if filter_result.violates_policy?
        ActivityLogger.log(
          account: sender,
          event: "CHAT_MESSAGE_CONTACT_INFO_DROPPED",
          title: "Silently dropped message attempting to share contact details",
          metadata: {
            conversation_id: conversation.id,
            reasons: filter_result.reasons,
            preview: content.to_s.truncate(100)
          }
        )

        # Silent drop: Return a transient message object for the sender so the client
        # appears to have succeeded, but never save, broadcast, or notify the recipient.
        return ChatMessage.new(
          id: (Time.current.to_f * 1000).to_i,
          chat_conversation: conversation,
          chat_conversation_id: conversation.id,
          chat_session: chat_session,
          chat_session_id: chat_session.id,
          sender_account: sender,
          sender_account_id: sender.id,
          content: content,
          sent_at: Time.current,
          message_type: :text,
          metadata: {}
        )
      end

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
        title: "New message from #{sender.full_name}",
        body: message.content.truncate(80),
        payload: { chat_conversation_id: conversation.id, chat_session_id: chat_session.id, last_chat_message_id: message.id },
        push: true,
        collapse: true
      )
      ActivityLogger.log(account: sender, event: "CHAT_MESSAGE_SENT", title: "Sent message to #{recipient_account.full_name}")
      message
    end

    private

    attr_reader :conversation, :sender

    def recipient_account
      conversation.other_participant_for(sender)
    end
  end
end
