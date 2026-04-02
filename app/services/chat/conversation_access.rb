module Chat
  class ConversationAccess
    class Error < StandardError; end

    def self.ensure_customer_can_start!(customer:, business_profile:)
      raise Error, "Business profile is not available for chat" unless business_profile.approved? && business_profile.currently_available?
      raise Error, "Only normal users can start business chats" if customer.business_account?
      raise Error, "You cannot chat with your own business profile" if business_profile.account_id == customer.id
      raise Error, "Chat pricing is not configured" unless business_profile.chat_price_cents.positive?
      raise Error, "Insufficient wallet balance for one minute chat" if customer.wallet_balance_cents < business_profile.chat_price_cents
    end

    def self.ensure_participant!(conversation:, account:)
      return if conversation.participants_include?(account)

      raise Error, "You are not allowed to access this conversation"
    end
  end
end
