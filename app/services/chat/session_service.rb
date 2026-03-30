module Chat
  class SessionService
    class Error < StandardError; end

    def initialize(conversation:, actor:)
      @conversation = conversation
      @actor = actor
    end

    def request_chat!
      business_profile = conversation.business_profile
      Chat::ConversationAccess.ensure_customer_can_start!(customer: actor, business_profile: business_profile)
      existing_session = conversation.active_or_requested_session
      raise Error, "A chat request is already active for this conversation" if existing_session.present?

      ActiveRecord::Base.transaction do
        session = conversation.chat_sessions.create!(
          customer_account: actor,
          business_profile: business_profile,
          status: :requested,
          price_per_minute_cents: business_profile.chat_price_cents,
          requested_at: Time.current
        )
        ExpireChatSessionJob.set(wait_until: session.expires_at).perform_later(session.id)
        Chat::Broadcaster.broadcast_to_conversation(conversation, {
          type: "chat_session",
          event: "session_requested",
          session: ChatSessionBlueprint.render_as_hash(session)
        })
        Notifications::Creator.call(
          recipient: business_profile.account,
          actor: actor,
          notifiable: session,
          notification_type: "chat_request_received",
          title: "New chat request",
          body: "#{actor.full_name} wants to start a paid chat with you.",
          payload: { chat_conversation_id: conversation.id, chat_session_id: session.id, business_profile_id: business_profile.id }
        )
        session
      end
    end

    def accept!(chat_session)
      ensure_business_owner!
      raise Error, "Only requested sessions can be accepted" unless chat_session.requested?

      chat_session.update!(
        status: :active,
        started_at: Time.current,
        last_billed_at: Time.current,
        end_reason: nil
      )
      Chat::BillingService.new(chat_session).charge_upfront_first_minute!
      chat_session.reload

      Chat::Broadcaster.broadcast_to_conversation(conversation, {
        type: "chat_session",
        event: "session_started",
        session: ChatSessionBlueprint.render_as_hash(chat_session)
      })
      Notifications::Creator.call(
        recipient: conversation.customer_account,
        actor: actor,
        notifiable: chat_session,
        notification_type: "chat_request_accepted",
        title: "Chat request accepted",
        body: "#{conversation.business_profile.business_name} accepted your chat request.",
        payload: { chat_conversation_id: conversation.id, chat_session_id: chat_session.id }
      )
      chat_session
    end

    def decline!(chat_session)
      ensure_business_owner!
      raise Error, "Only requested sessions can be declined" unless chat_session.requested?

      chat_session.update!(status: :declined, ended_at: Time.current, end_reason: "declined_by_business")
      Chat::Broadcaster.broadcast_to_conversation(conversation, {
        type: "chat_session",
        event: "session_declined",
        session: ChatSessionBlueprint.render_as_hash(chat_session)
      })
      Notifications::Creator.call(
        recipient: conversation.customer_account,
        actor: actor,
        notifiable: chat_session,
        notification_type: "chat_request_declined",
        title: "Chat request declined",
        body: "#{conversation.business_profile.business_name} declined your chat request.",
        payload: { chat_conversation_id: conversation.id, chat_session_id: chat_session.id }
      )
      chat_session
    end

    def end!(chat_session, reason:)
      raise Error, "Session is already closed" if chat_session.ended?
      ensure_participant!

      Chat::BillingService.new(chat_session).sync!
      chat_session.reload
      return chat_session if chat_session.ended?

      chat_session.update!(status: :ended, ended_at: Time.current, end_reason: reason)
      Chat::Broadcaster.broadcast_to_conversation(conversation, {
        type: "chat_session",
        event: "session_ended",
        session: ChatSessionBlueprint.render_as_hash(chat_session)
      })
      recipient = actor.id == conversation.customer_account_id ? conversation.business_profile.account : conversation.customer_account
      Notifications::Creator.call(
        recipient: recipient,
        actor: actor,
        notifiable: chat_session,
        notification_type: "chat_session_ended",
        title: "Chat ended",
        body: "Your paid chat session has ended.",
        payload: { chat_conversation_id: conversation.id, chat_session_id: chat_session.id, reason: reason }
      )
      chat_session
    end

    private

    attr_reader :conversation, :actor

    def ensure_business_owner!
      return if conversation.business_profile.account_id == actor.id

      raise Error, "Only the business user can perform this action"
    end

    def ensure_participant!
      return if conversation.participants_include?(actor)

      raise Error, "You are not allowed to perform this action"
    end
  end
end
