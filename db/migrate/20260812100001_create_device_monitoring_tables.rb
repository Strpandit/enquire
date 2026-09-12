class CreateDeviceMonitoringTables < ActiveRecord::Migration[7.1]
  def change
    create_table :devices do |t|
      t.references :account, foreign_key: true, index: true
      t.string :device_uuid, null: false, index: true
      t.string :manufacturer
      t.string :model
      t.string :android_version
      t.integer :android_api_level
      t.string :app_version, default: "1.0.0"
      t.integer :app_build, default: 1
      t.string :network_type
      t.string :last_ip
      t.string :push_token
      t.datetime :first_seen_at
      t.datetime :last_seen_at

      t.timestamps
    end

    create_table :device_sessions do |t|
      t.references :account, foreign_key: true, index: true
      t.references :device, foreign_key: true, index: true
      t.string :ip_address
      t.string :network_type
      t.datetime :login_at
      t.datetime :last_seen_at
      t.datetime :logout_at
      t.string :app_version
      t.string :android_version

      t.timestamps
    end

    create_table :activity_logs do |t|
      t.references :account, foreign_key: true, index: true
      t.references :device, foreign_key: true, index: true
      t.string :event, null: false, index: true
      t.string :title
      t.jsonb :metadata, default: {}
      t.string :ip_address

      t.timestamps
    end

    add_index :devices, [ :account_id, :device_uuid ], unique: true
  end
end
