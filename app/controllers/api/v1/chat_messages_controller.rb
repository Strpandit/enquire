module Api
  module V1
    class ChatMessagesController < BaseController
      rescue_from Chat::ConversationAccess::Error, Chat::MessageService::Error, with: :render_chat_error

      def index
        conversation = find_conversation
        Chat::ReadReceiptService.new(conversation: conversation, reader: current_account).mark_all_read! if mark_read_param?

        messages_scope = conversation.chat_messages
                                     .includes(:sender_account)
                                     .order(created_at: :asc)

        messages_scope = messages_scope.before_id(params[:before_id]) if params[:before_id].present?
        messages = messages_scope.last(per_page)

        render json: {
          chat_messages: ChatMessageBlueprint.render_as_hash(messages),
          has_more: has_more?(conversation, messages)
        }, status: :ok
      end

      def create
        conversation = find_conversation
        message = Chat::MessageService.new(
          conversation: conversation,
          sender: current_account
        ).create!(
          content: message_content,
          attachments: message_attachments
        )

        render json: {
          message: "Message sent successfully",
          chat_message: ChatMessageBlueprint.render_as_hash(message)
        }, status: :created
      end

      def mark_read
        conversation = find_conversation
        read_at = Chat::ReadReceiptService.new(conversation: conversation, reader: current_account).mark_all_read!

        render json: {
          message: "Messages marked as read",
          read_at: read_at
        }, status: :ok
      end

      private

      def find_conversation
        conversation = ChatConversation
                         .includes(:customer_account, business_profile: :account)
                         .find(params[:chat_conversation_id])
        Chat::ConversationAccess.ensure_participant!(conversation: conversation, account: current_account)
        conversation
      end

      def message_content
        params[:content].to_s.strip.presence || ""
      end

      def message_attachments
        raw = params[:attachments]
        return [] if raw.blank?

        Array(raw).compact.first(ChatMessage::MAX_ATTACHMENTS_PER_MSG)
      end

      def mark_read_param?
        ActiveModel::Type::Boolean.new.cast(params[:mark_read])
      end

      def per_page
        [ (params[:per] || 40).to_i, 100 ].min
      end

      def has_more?(conversation, messages)
        return false if messages.empty?

        conversation.chat_messages.where("id < ?", messages.first.id).exists?
      end

      def render_chat_error(error)
        render json: { errors: [ error.message ] }, status: :unprocessable_entity
      end
    end
  end
end
