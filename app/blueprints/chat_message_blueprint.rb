class ChatMessageBlueprint < Blueprinter::Base
  identifier :id

  fields :chat_conversation_id, :chat_session_id, :sender_account_id, :message_type, :content, :sent_at, :read_at, :metadata

  field :sender do |message|
    {
      id: message.sender_account.id,
      uid: message.sender_account.uid,
      full_name: message.sender_account.full_name,
      username: message.sender_account.username
    }
  end
end
