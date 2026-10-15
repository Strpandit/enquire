module Api
  module V1
    class ChatConversationsController < BaseController
      rescue_from Chat::ConversationAccess::Error, Chat::SessionService::Error, with: :render_chat_error

      def index
        conversations = scope_conversations.includes(customer_account: { profile_pic_attachment: :blob }, business_profile: { account: { profile_pic_attachment: :blob } }).recent_first.page(params[:page]).per(per_page)

        render json: {
          chat_conversations: ChatConversationBlueprint.render_as_hash(
            conversations,
            viewer: current_account,
            unread_counts: unread_counts_for(conversations),
            active_sessions: active_sessions_for(conversations),
            presence: presence_for(conversations)
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
        ChatConversation.joins(:business_profile)
                        .where("chat_conversations.customer_account_id = :id OR business_profiles.account_id = :id", id: current_account.id)
      end

      def find_conversation
        conversation = ChatConversation.includes(:customer_account, business_profile: :account).find(params[:id])
        Chat::ConversationAccess.ensure_participant!(conversation: conversation, account: current_account)
        conversation
      end

      def unread_counts_for(conversations)
        conversation_ids = Array(conversations).map(&:id)
        return {} if conversation_ids.empty?

        counts = Hash.new(0)
        Array(conversations).group_by do |conversation|
          conversation.customer_account_id == current_account.id ? conversation.last_read_by_customer_at : conversation.last_read_by_business_at
        end.each do |cutoff, group|
          scope = ChatMessage.where(chat_conversation_id: group.map(&:id))
                             .where.not(sender_account_id: current_account.id)
          scope = scope.where("created_at > ?", cutoff) if cutoff.present?
          scope.group(:chat_conversation_id).count.each { |id, count| counts[id] = count }
        end
        conversation_ids.index_with { |id| counts[id] }
      end

      def presence_for(conversations)
        account_ids = Array(conversations).flat_map do |conversation|
          [ conversation.customer_account_id, conversation.business_profile.account_id ]
        end.uniq
        return {} if account_ids.empty?

        keys = account_ids.index_by { |id| "account_presence:#{id}" }
        cached = Rails.cache.read_multi(*keys.keys)
        account_ids.index_with { |id| cached["account_presence:#{id}"] == true }
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
