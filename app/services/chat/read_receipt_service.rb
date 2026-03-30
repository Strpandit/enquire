module Chat
  class ReadReceiptService
    def initialize(conversation:, reader:)
      @conversation = conversation
      @reader = reader
    end

    def mark_all_read!
      timestamp = Time.current
      conversation.transaction do
        conversation.mark_read_for!(reader, timestamp: timestamp)
        conversation.chat_messages
                    .where.not(sender_account_id: reader.id)
                    .unread
                    .update_all(read_at: timestamp, updated_at: timestamp)
      end

      Chat::Broadcaster.broadcast_to_conversation(conversation, {
        type: "read_receipt",
        event: "messages_read",
        conversation_id: conversation.id,
        reader_account_id: reader.id,
        read_at: timestamp
      })
      timestamp
    end

    private

    attr_reader :conversation, :reader
  end
end
