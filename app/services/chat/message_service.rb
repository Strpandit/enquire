module Chat
  class MessageService
    class Error < StandardError; end

    ALLOWED_CONTENT_TYPES = ChatMessage::ALLOWED_ATTACHMENT_CONTENT_TYPES
    IMAGE_CONTENT_TYPES   = ChatMessage::IMAGE_CONTENT_TYPES

    def initialize(conversation:, sender:)
      @conversation = conversation
      @sender       = sender
    end

    def create!(content:, attachments: [])
      Chat::ConversationAccess.ensure_participant!(conversation: conversation, account: sender)
      chat_session = conversation.active_or_requested_session
      raise Error, "No active chat session found" unless chat_session&.active?

      Chat::BillingService.new(chat_session).sync!
      chat_session.reload
      raise Error, "Chat session is no longer active" unless chat_session.active?

      attachments = Array(attachments).compact

      attachments.each do |file|
        ct = file.content_type.to_s.downcase
        unless ALLOWED_CONTENT_TYPES.include?(ct)
          raise Error, "#{file.original_filename} — type not allowed. Only images and documents are permitted."
        end
      end

      msg_type = resolve_message_type(content, attachments)

      effective_content = content.to_s.strip.presence || attachment_fallback_content(attachments)

      if msg_type == :text && effective_content.present?
        filter_result = Chat::SecurityFilter.analyze(effective_content)
        if filter_result.violates_policy?
          ActivityLogger.log(
            account: sender,
            event: "CHAT_MESSAGE_CONTACT_INFO_DROPPED",
            title: "Silently dropped message attempting to share contact details",
            metadata: {
              conversation_id: conversation.id,
              reasons: filter_result.reasons,
              preview: effective_content.to_s.truncate(100)
            }
          )

          return ChatMessage.new(
            id: (Time.current.to_f * 1000).to_i,
            chat_conversation: conversation,
            chat_conversation_id: conversation.id,
            chat_session: chat_session,
            chat_session_id: chat_session.id,
            sender_account: sender,
            sender_account_id: sender.id,
            content: effective_content,
            sent_at: Time.current,
            message_type: :text,
            metadata: {}
          )
        end
      end

      message = nil
      ActiveRecord::Base.transaction do
        message = conversation.chat_messages.create!(
          chat_session: chat_session,
          sender_account: sender,
          content: effective_content,
          sent_at: Time.current,
          message_type: msg_type
        )

        message.attachments.attach(attachments) if attachments.any?

        conversation.update!(
          last_message_at: message.sent_at,
          last_message_preview: last_message_preview(effective_content, msg_type, attachments)
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
        body: notification_body(effective_content, msg_type, attachments),
        payload: {
          chat_conversation_id: conversation.id,
          chat_session_id: chat_session.id,
          last_chat_message_id: message.id
        },
        push: true,
        collapse: true
      )

      message
    end

    private

    attr_reader :conversation, :sender

    def recipient_account
      conversation.other_participant_for(sender)
    end

    def resolve_message_type(content, attachments)
      return :text if attachments.empty?

      image_types  = attachments.select { |f| IMAGE_CONTENT_TYPES.include?(f.content_type.to_s.downcase) }
      doc_types    = attachments.reject { |f| IMAGE_CONTENT_TYPES.include?(f.content_type.to_s.downcase) }

      return :image    if image_types.any? && doc_types.empty?
      return :document if doc_types.any?  && image_types.empty?
      :media
    end

    def attachment_fallback_content(attachments)
      return "" if attachments.empty?

      names = attachments.map { |f| f.original_filename.presence || "attachment" }
      names.join(", ")
    end

    def last_message_preview(content, msg_type, attachments)
      count = attachments.size
      case msg_type
      when :image
        label = count > 1 ? "#{count} Images" : "Image"
        content.present? ? "📷 #{label}: #{content.truncate(60)}" : "📷 #{label}"
      when :document
        label = count > 1 ? "#{count} Documents" : "Document"
        content.present? ? "📄 #{label}: #{content.truncate(60)}" : "📄 #{label}"
      when :media
        "📎 #{count} file#{count > 1 ? 's' : ''}"
      else
        content.to_s.truncate(120)
      end
    end

    def notification_body(content, msg_type, attachments)
      count = attachments.size
      case msg_type
      when :image
        count > 1 ? "📷 Sent #{count} images" : "📷 Sent an image"
      when :document
        count > 1 ? "📄 Sent #{count} documents" : "📄 Sent a document"
      when :media
        "📎 Sent #{count} files"
      else
        content.to_s.truncate(80)
      end
    end
  end
end
