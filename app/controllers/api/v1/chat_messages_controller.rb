module Api
  module V1
    class ChatMessagesController < BaseController
      rescue_from Chat::ConversationAccess::Error, Chat::MessageService::Error, with: :render_chat_error

      def index
        conversation = find_conversation
        messages = conversation.chat_messages.includes(:sender_account).order(created_at: :desc).page(params[:page]).per(per_page)
        Chat::ReadReceiptService.new(conversation: conversation, reader: current_account).mark_all_read! if ActiveModel::Type::Boolean.new.cast(params[:mark_read])

        render json: {
          chat_messages: ChatMessageBlueprint.render_as_hash(messages),
          meta: pagination_meta(messages)
        }, status: :ok
      end

      def create
        conversation = find_conversation
        message = Chat::MessageService.new(conversation: conversation, sender: current_account).create!(content: message_params[:content])

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
        conversation = ChatConversation.includes(:customer_account, business_profile: :account).find(params[:chat_conversation_id])
        Chat::ConversationAccess.ensure_participant!(conversation: conversation, account: current_account)
        conversation
      end

      def message_params
        params.require(:chat_message).permit(:content)
      end

      def render_chat_error(error)
        render json: { errors: [ error.message ] }, status: :unprocessable_entity
      end
    end
  end
end
