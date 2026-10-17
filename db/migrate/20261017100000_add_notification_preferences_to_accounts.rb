class AddNotificationPreferencesToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :notification_preferences, :jsonb, null: false, default: {}
  end
end
