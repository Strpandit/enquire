class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts do |t|
      t.string :full_name
      t.string :email
      t.bigint :phone
      t.string :state
      t.string :district
      t.string :city
      t.integer :pincode, limit: 6
      t.string :password_digest
      t.string :otp_pin
      t.datetime :otp_sent_at
      t.string :reset_password_token_digest
      t.datetime :reset_password_sent_at
      t.datetime :deleted_at
      t.boolean :is_business, default: false
      t.boolean :is_verified, default: false
      t.string :username
      t.string :languages, default: "[]"
      t.integer :verification_status, default: 0, null: false
      t.text :verification_rejection_reason
      t.datetime :verified_at

      t.timestamps
    end

    add_index :accounts, "LOWER(email)", unique: true, name: "index_accounts_on_lower_email"
    add_index :accounts, "LOWER(username)", unique: true, name: "index_accounts_on_lower_username"
    add_index :accounts, :phone, unique: true
    add_index :accounts, :reset_password_token_digest, unique: true
  end
end
