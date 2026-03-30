module Api
  module V1
    class ChatSessionsController < BaseController
      rescue_from Chat::ConversationAccess::Error, Chat::SessionService::Error, Chat::BillingService::Error, with: :render_chat_error

      def index
        conversation = find_conversation
        sessions = conversation.chat_sessions.order(created_at: :desc).page(params[:page]).per(per_page)
        render json: {
          chat_sessions: ChatSessionBlueprint.render_as_hash(sessions),
          meta: pagination_meta(sessions)
        }, status: :ok
      end

      def accept
        conversation = find_conversation
        session = find_session(conversation)
        session = Chat::SessionService.new(conversation: conversation, actor: current_account).accept!(session)

        render json: {
          message: "Chat session started",
          chat_session: ChatSessionBlueprint.render_as_hash(session)
        }, status: :ok
      end

      def decline
        conversation = find_conversation
        session = find_session(conversation)
        session = Chat::SessionService.new(conversation: conversation, actor: current_account).decline!(session)

        render json: {
          message: "Chat request declined",
          chat_session: ChatSessionBlueprint.render_as_hash(session)
        }, status: :ok
      end

      def end_session
        conversation = find_conversation
        session = find_session(conversation)
        session = Chat::SessionService.new(conversation: conversation, actor: current_account).end!(session, reason: end_reason)

        render json: {
          message: "Chat session ended",
          chat_session: ChatSessionBlueprint.render_as_hash(session)
        }, status: :ok
      end

      def heartbeat
        conversation = find_conversation
        session = find_session(conversation)
        Chat::ConversationAccess.ensure_participant!(conversation: conversation, account: current_account)
        session = Chat::BillingService.new(session).sync!

        render json: {
          message: "Heartbeat synced",
          chat_session: ChatSessionBlueprint.render_as_hash(session)
        }, status: :ok
      end

      private

      def find_conversation
        conversation = ChatConversation.find(params[:chat_conversation_id])
        Chat::ConversationAccess.ensure_participant!(conversation: conversation, account: current_account)
        conversation
      end

      def find_session(conversation)
        conversation.chat_sessions.find(params[:id])
      end

      def end_reason
        params[:reason].presence || "ended by user"
      end

      def render_chat_error(error)
        render json: { errors: [ error.message ] }, status: :unprocessable_entity
      end
    end
  end
end
