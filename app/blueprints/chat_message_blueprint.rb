class ChatMessageBlueprint < Blueprinter::Base
  identifier :id

  fields :chat_conversation_id, :chat_session_id, :sender_account_id,
         :message_type, :content, :sent_at, :read_at, :metadata

  field :sender do |message|
    {
      id: message.sender_account.id,
      uid: message.sender_account.uid,
      full_name: message.sender_account.full_name,
      username: message.sender_account.username,
      profile_pic_url: message.sender_account.profile_pic.attached? \
        ? Rails.application.routes.url_helpers.url_for(message.sender_account.profile_pic) \
        : nil
    }
  end

  field :attachments do |message|
    next [] unless message.attachments.attached?

    message.attachments.map do |attachment|
      blob = attachment.blob
      next nil unless blob

      {
        url: Rails.application.routes.url_helpers.url_for(attachment),
        filename: blob.filename.to_s,
        content_type: blob.content_type.to_s,
        byte_size: blob.byte_size,
        is_image: ChatMessage::IMAGE_CONTENT_TYPES.include?(blob.content_type.to_s.downcase)
      }
    rescue StandardError
      nil
    end.compact
  end
end
