module Chat
  class Broadcaster
    def self.broadcast_to_conversation(conversation, payload)
      ActionCable.server.broadcast("chat_conversation_#{conversation.id}", payload)
    end
  end
end
