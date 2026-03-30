class ChatConversationBlueprint < Blueprinter::Base
  identifier :id

  fields :customer_account_id, :business_profile_id, :status, :last_message_at, :last_message_preview, :created_at, :updated_at

  field :customer do |conversation|
    customer = conversation.customer_account
    {
      id: customer.id,
      uid: customer.uid,
      full_name: customer.full_name,
      username: customer.username,
      online: customer.online?,
      last_seen_at: customer.last_seen_at
    }
  end

  field :business do |conversation|
    profile = conversation.business_profile
    owner = profile.account
    {
      id: profile.id,
      business_name: profile.business_name,
      account_id: profile.account_id,
      account_uid: owner.uid,
      chat_price: profile.chat_price,
      is_available: profile.is_available,
      online: owner.online?,
      last_seen_at: owner.last_seen_at
    }
  end

  field :active_session do |conversation, options|
    session = options.dig(:active_sessions, conversation.id) || conversation.active_or_requested_session
    session && ChatSessionBlueprint.render_as_hash(session)
  end

  field :unread_count do |conversation, options|
    options.dig(:unread_counts, conversation.id) || 0
  end
end
