module Api
  module V1
    class ChatRequestsController < BaseController
      rescue_from Chat::ConversationAccess::Error, Chat::SessionService::Error, with: :render_chat_error

      def create
        business_profile = BusinessProfile.find(params[:business_profile_id])
        conversation = ChatConversation.find_or_create_by!(customer_account: current_account, business_profile: business_profile)
        session = Chat::SessionService.new(conversation: conversation, actor: current_account).request_chat!

        render json: {
          message: "Chat request sent successfully",
          chat_conversation: ChatConversationBlueprint.render_as_hash(conversation.reload),
          chat_session: ChatSessionBlueprint.render_as_hash(session)
        }, status: :created
      end

      private

      def render_chat_error(error)
        render json: { errors: [ error.message ] }, status: :unprocessable_entity
      end
    end
  end
end
