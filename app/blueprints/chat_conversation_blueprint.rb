class ChatConversationBlueprint < Blueprinter::Base
  identifier :id

  fields :customer_account_id, :business_profile_id, :status, :last_message_at, :last_message_preview, :created_at, :updated_at

  field :customer do |conversation, options|
    customer = conversation.customer_account
    {
      id: customer.id,
      uid: customer.uid,
      full_name: customer.full_name,
      username: customer.username,
      online: options[:presence] ? options[:presence].fetch(customer.id, false) : customer.online?,
      last_seen_at: customer.last_seen_at,
      profile_pic_url: customer.profile_pic_url
    }
  end

  field :business do |conversation, options|
    profile = conversation.business_profile
    owner = profile.account
    {
      id: profile.id,
      business_name: profile.business_name,
      account_id: profile.account_id,
      account_uid: owner.uid,
      full_name: owner.full_name,
      is_verified: owner.is_verified?,
      chat_price: profile.chat_price,
      is_available: profile.currently_available?,
      online: options[:presence] ? options[:presence].fetch(owner.id, false) : owner.online?,
      last_seen_at: owner.last_seen_at,
      profile_pic_url: owner.profile_pic_url
    }
  end

  field :active_session do |conversation, options|
    session = if options[:active_sessions]
      options[:active_sessions][conversation.id]
    else
      conversation.active_or_requested_session
    end
    session && ChatSessionBlueprint.render_as_hash(session)
  end

  field :unread_count do |conversation, options|
    options.dig(:unread_counts, conversation.id) || 0
  end
end
