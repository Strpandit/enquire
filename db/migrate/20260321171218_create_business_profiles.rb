class CreateBusinessProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :business_profiles do |t|
      t.references :account, null: false, foreign_key: true
      t.decimal :chat_price, precision: 8, scale: 2
      t.decimal :call_price, precision: 8, scale: 2
      t.decimal :v_call_price, precision: 8, scale: 2
      t.boolean :is_available, default: true
      t.boolean :gst_enabled, default: false
      t.string :gst_number
      t.integer :pincode, limit: 6
      t.string :state
      t.string :city
      t.string :business_name
      t.text :business_address
      t.string :bio
      t.text :about
      t.decimal :avg_rating, precision: 3, scale: 2, default: 0.0
      t.integer :reviews_count, default: 0
      t.integer :approval_status, default: 0, null: false
      t.text :rejection_reason
      t.datetime :approved_at
      t.string :share_token

      t.timestamps
    end

    add_index :business_profiles, :gst_number, unique: true
    add_index :business_profiles, :share_token, unique: true
  end
end
