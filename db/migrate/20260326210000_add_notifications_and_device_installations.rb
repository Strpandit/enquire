class AddNotificationsAndDeviceInstallations < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :recipient_account, null: false, foreign_key: { to_table: :accounts }
      t.references :actor_account, foreign_key: { to_table: :accounts }
      t.string :notification_type, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.string :notifiable_type
      t.bigint :notifiable_id
      t.datetime :read_at
      t.datetime :push_sent_at
      t.jsonb :payload, default: {}

      t.timestamps
    end

    add_index :notifications, [ :notifiable_type, :notifiable_id ], name: "idx_notifications_on_notifiable"
    add_index :notifications, [ :recipient_account_id, :read_at ], name: "idx_notifications_on_recipient_and_read_at"

    create_table :device_installations do |t|
      t.references :account, null: false, foreign_key: true
      t.integer :platform, null: false, default: 0
      t.string :device_token, null: false
      t.string :device_id
      t.boolean :active, null: false, default: true
      t.datetime :last_seen_at
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :device_installations, :device_token, unique: true
    add_index :device_installations, [ :account_id, :active ], name: "idx_device_installations_on_account_and_active"
  end
end
