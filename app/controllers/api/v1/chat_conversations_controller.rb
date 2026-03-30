module Api
  module V1
    class ChatConversationsController < BaseController
      rescue_from Chat::ConversationAccess::Error, Chat::SessionService::Error, with: :render_chat_error

      def index
        conversations = scope_conversations.includes(:customer_account, business_profile: :account).recent_first.page(params[:page]).per(per_page)

        render json: {
          chat_conversations: ChatConversationBlueprint.render_as_hash(
            conversations,
            viewer: current_account,
            unread_counts: unread_counts_for(conversations),
            active_sessions: active_sessions_for(conversations)
          ),
          meta: pagination_meta(conversations)
        }, status: :ok
      end

      def show
        conversation = find_conversation
        render json: {
          chat_conversation: ChatConversationBlueprint.render_as_hash(
            conversation,
            viewer: current_account,
            unread_counts: unread_counts_for([ conversation ]),
            active_sessions: active_sessions_for([ conversation ])
          )
        }, status: :ok
      end

      def create
        business_profile = BusinessProfile.find(params.require(:business_profile_id))
        Chat::ConversationAccess.ensure_customer_can_start!(customer: current_account, business_profile: business_profile)

        conversation = ChatConversation.find_or_create_by!(customer_account: current_account, business_profile: business_profile)
        render json: {
          message: "Conversation ready",
          chat_conversation: ChatConversationBlueprint.render_as_hash(
            conversation,
            viewer: current_account,
            unread_counts: unread_counts_for([ conversation ]),
            active_sessions: active_sessions_for([ conversation ])
          )
        }, status: :ok
      end

      private

      def scope_conversations
        if current_account.business_account?
          ChatConversation.joins(:business_profile).where(business_profiles: { account_id: current_account.id })
        else
          current_account.customer_chat_conversations
        end
      end

      def find_conversation
        conversation = ChatConversation.includes(:customer_account, business_profile: :account).find(params[:id])
        Chat::ConversationAccess.ensure_participant!(conversation: conversation, account: current_account)
        conversation
      end

      def unread_counts_for(conversations)
        conversation_ids = Array(conversations).map(&:id)
        return {} if conversation_ids.empty?

        messages_by_conversation = ChatMessage.where(chat_conversation_id: conversation_ids)
                                              .where.not(sender_account_id: current_account.id)
                                              .pluck(:chat_conversation_id, :created_at)
                                              .group_by(&:first)

        Array(conversations).each_with_object({}) do |conversation, counts|
          cutoff = conversation.customer_account_id == current_account.id ? conversation.last_read_by_customer_at : conversation.last_read_by_business_at
          messages = messages_by_conversation.fetch(conversation.id, [])
          counts[conversation.id] = if cutoff.present?
            messages.count { |_conversation_id, created_at| created_at > cutoff }
          else
            messages.size
          end
        end
      end

      def active_sessions_for(conversations)
        conversation_ids = Array(conversations).map(&:id)
        return {} if conversation_ids.empty?

        ChatSession.where(chat_conversation_id: conversation_ids, status: [ :requested, :active ])
                   .order(created_at: :desc)
                   .group_by(&:chat_conversation_id)
                   .transform_values(&:first)
      end

      def render_chat_error(error)
        render json: { errors: [ error.message ] }, status: :unprocessable_entity
      end
    end
  end
end
