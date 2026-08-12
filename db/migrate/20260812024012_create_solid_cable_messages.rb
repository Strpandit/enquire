class CreateSolidCableMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :solid_cable_messages do |t|
      t.binary :channel, null: false, limit: 1024
      t.binary :payload, null: false, limit: 536870912
      t.timestamps
      t.bigint :channel_hash, null: false
    end

    add_index :solid_cable_messages, :channel
    add_index :solid_cable_messages, :channel_hash
    add_index :solid_cable_messages, :created_at
  end
end
