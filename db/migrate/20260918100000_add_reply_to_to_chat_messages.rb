class AddReplyToToChatMessages < ActiveRecord::Migration[8.0]
  def change
    add_reference :chat_messages, :reply_to, foreign_key: { to_table: :chat_messages }, index: true, null: true
  end
end
