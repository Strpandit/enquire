class AddMediaSupportToChatMessages < ActiveRecord::Migration[8.0]
  def up
    change_column_null :chat_messages, :content, true
  end

  def down
    ChatMessage.where(content: nil).update_all(content: "")
    change_column_null :chat_messages, :content, false
  end
end
