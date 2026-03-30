class ChatConversation < ApplicationRecord
  belongs_to :customer_account, class_name: "Account"
  belongs_to :business_profile

  has_many :chat_messages, dependent: :destroy
  has_many :chat_sessions, dependent: :destroy

  enum :status, { active: 0, archived: 1 }, default: :active

  validates :customer_account_id, uniqueness: { scope: :business_profile_id }

  scope :recent_first, -> { order(last_message_at: :desc, updated_at: :desc) }

  def participants_include?(account)
    customer_account_id == account.id || business_profile.account_id == account.id
  end

  def business_owner_account
    business_profile.account
  end

  def other_participant_for(account)
    customer_account_id == account.id ? business_owner_account : customer_account
  end

  def active_or_requested_session
    sessions = if association(:chat_sessions).loaded?
      chat_sessions
    else
      chat_sessions.where(status: [ :requested, :active ]).order(created_at: :desc)
    end

    sessions.select { |session| session.status.in?(["requested", "active"]) }.max_by(&:created_at)
  end

  def unread_count_for(account, messages: nil)
    cutoff = if customer_account_id == account.id
      last_read_by_customer_at
    elsif business_profile.account_id == account.id
      last_read_by_business_at
    end

    source = messages || (association(:chat_messages).loaded? ? chat_messages : chat_messages.where.not(sender_account_id: account.id))
    collection = source.reject { |message| message.sender_account_id == account.id }
    return collection.count if cutoff.blank?

    collection.count { |message| message.created_at > cutoff }
  end

  def mark_read_for!(account, timestamp: Time.current)
    if customer_account_id == account.id
      update!(last_read_by_customer_at: timestamp)
    elsif business_profile.account_id == account.id
      update!(last_read_by_business_at: timestamp)
    else
      raise ActiveRecord::RecordNotFound, "Conversation not found"
    end
  end
end
