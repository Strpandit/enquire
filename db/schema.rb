# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_03_30_124500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "full_name"
    t.string "email"
    t.bigint "phone"
    t.string "state"
    t.string "district"
    t.string "city"
    t.bigint "pincode"
    t.string "password_digest"
    t.string "otp_pin"
    t.datetime "otp_sent_at"
    t.string "reset_password_token_digest"
    t.datetime "reset_password_sent_at"
    t.datetime "deleted_at"
    t.boolean "is_business", default: false
    t.boolean "is_verified", default: false
    t.string "username"
    t.string "languages", default: "[]"
    t.integer "verification_status", default: 0, null: false
    t.text "verification_rejection_reason"
    t.datetime "verified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "wallet_balance_cents", default: 0, null: false
    t.string "uid"
    t.datetime "last_seen_at"
    t.index "lower((email)::text)", name: "index_accounts_on_lower_email", unique: true
    t.index "lower((username)::text)", name: "index_accounts_on_lower_username", unique: true, where: "(username IS NOT NULL)"
    t.index ["phone"], name: "index_accounts_on_phone", unique: true
    t.index ["reset_password_token_digest"], name: "index_accounts_on_reset_password_token_digest", unique: true
    t.index ["uid"], name: "index_accounts_on_uid", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "business_profile_categories", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.bigint "business_profile_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_profile_id", "category_id"], name: "idx_on_business_profile_id_category_id_4967096322", unique: true
    t.index ["business_profile_id"], name: "index_business_profile_categories_on_business_profile_id"
    t.index ["category_id"], name: "index_business_profile_categories_on_category_id"
  end

  create_table "business_profiles", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.decimal "chat_price", precision: 8, scale: 2
    t.decimal "call_price", precision: 8, scale: 2
    t.decimal "v_call_price", precision: 8, scale: 2
    t.boolean "is_available", default: true
    t.boolean "gst_enabled", default: false
    t.string "gst_number"
    t.bigint "pincode"
    t.string "state"
    t.string "city"
    t.string "business_name"
    t.text "business_address"
    t.string "bio"
    t.text "about"
    t.decimal "avg_rating", precision: 3, scale: 2, default: "0.0"
    t.integer "reviews_count", default: 0
    t.integer "approval_status", default: 0, null: false
    t.text "rejection_reason"
    t.datetime "approved_at"
    t.string "share_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_business_profiles_on_account_id"
    t.index ["gst_number"], name: "index_business_profiles_on_gst_number", unique: true
    t.index ["share_token"], name: "index_business_profiles_on_share_token", unique: true
  end

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_categories_on_lower_name", unique: true
  end

  create_table "chat_conversations", force: :cascade do |t|
    t.bigint "customer_account_id", null: false
    t.bigint "business_profile_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "last_message_at"
    t.text "last_message_preview"
    t.datetime "last_read_by_customer_at"
    t.datetime "last_read_by_business_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_profile_id"], name: "index_chat_conversations_on_business_profile_id"
    t.index ["customer_account_id", "business_profile_id"], name: "idx_chat_conversations_on_customer_and_business", unique: true
    t.index ["customer_account_id"], name: "index_chat_conversations_on_customer_account_id"
  end

  create_table "chat_messages", force: :cascade do |t|
    t.bigint "chat_conversation_id", null: false
    t.bigint "chat_session_id"
    t.bigint "sender_account_id", null: false
    t.integer "message_type", default: 0, null: false
    t.text "content", null: false
    t.datetime "sent_at", null: false
    t.datetime "read_at"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_conversation_id", "created_at"], name: "idx_chat_messages_on_conversation_and_created_at"
    t.index ["chat_conversation_id"], name: "index_chat_messages_on_chat_conversation_id"
    t.index ["chat_session_id"], name: "index_chat_messages_on_chat_session_id"
    t.index ["sender_account_id"], name: "index_chat_messages_on_sender_account_id"
  end

  create_table "chat_sessions", force: :cascade do |t|
    t.bigint "chat_conversation_id", null: false
    t.bigint "customer_account_id", null: false
    t.bigint "business_profile_id", null: false
    t.integer "status", default: 0, null: false
    t.integer "price_per_minute_cents", null: false
    t.datetime "requested_at", null: false
    t.datetime "started_at"
    t.datetime "ended_at"
    t.datetime "last_billed_at"
    t.integer "billable_seconds", default: 0, null: false
    t.integer "billed_minutes", default: 0, null: false
    t.integer "total_amount_cents", default: 0, null: false
    t.string "end_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_profile_id"], name: "index_chat_sessions_on_business_profile_id"
    t.index ["chat_conversation_id", "status"], name: "idx_chat_sessions_on_conversation_and_status"
    t.index ["chat_conversation_id"], name: "index_chat_sessions_on_chat_conversation_id"
    t.index ["customer_account_id"], name: "index_chat_sessions_on_customer_account_id"
  end

  create_table "device_installations", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.integer "platform", default: 0, null: false
    t.string "device_token", null: false
    t.string "device_id"
    t.boolean "active", default: true, null: false
    t.datetime "last_seen_at"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "active"], name: "idx_device_installations_on_account_and_active"
    t.index ["account_id"], name: "index_device_installations_on_account_id"
    t.index ["device_token"], name: "index_device_installations_on_device_token", unique: true
  end

  create_table "favorites", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "business_profile_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "business_profile_id"], name: "index_favorites_on_account_id_and_business_profile_id", unique: true
    t.index ["account_id"], name: "index_favorites_on_account_id"
    t.index ["business_profile_id"], name: "index_favorites_on_business_profile_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "recipient_account_id", null: false
    t.bigint "actor_account_id"
    t.string "notification_type", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.string "notifiable_type"
    t.bigint "notifiable_id"
    t.datetime "read_at"
    t.datetime "push_sent_at"
    t.jsonb "payload", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_account_id"], name: "index_notifications_on_actor_account_id"
    t.index ["notifiable_type", "notifiable_id"], name: "idx_notifications_on_notifiable"
    t.index ["recipient_account_id", "read_at"], name: "idx_notifications_on_recipient_and_read_at"
    t.index ["recipient_account_id"], name: "index_notifications_on_recipient_account_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "business_profile_id", null: false
    t.integer "rating", null: false
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "business_profile_id"], name: "index_reviews_on_account_id_and_business_profile_id", unique: true
    t.index ["account_id"], name: "index_reviews_on_account_id"
    t.index ["business_profile_id"], name: "index_reviews_on_business_profile_id"
  end

  create_table "schedules", force: :cascade do |t|
    t.bigint "business_profile_id", null: false
    t.integer "day_of_week"
    t.time "start_time"
    t.time "end_time"
    t.integer "availability_type", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_profile_id"], name: "index_schedules_on_business_profile_id"
  end

  create_table "wallet_transactions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "chat_session_id"
    t.integer "transaction_type", null: false
    t.integer "amount_cents", null: false
    t.integer "balance_after_cents", null: false
    t.string "entry_type", null: false
    t.string "reference_type"
    t.bigint "reference_id"
    t.string "description", null: false
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_wallet_transactions_on_account_id"
    t.index ["chat_session_id"], name: "index_wallet_transactions_on_chat_session_id"
    t.index ["reference_type", "reference_id"], name: "idx_wallet_transactions_on_reference"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "business_profile_categories", "business_profiles"
  add_foreign_key "business_profile_categories", "categories"
  add_foreign_key "business_profiles", "accounts"
  add_foreign_key "chat_conversations", "accounts", column: "customer_account_id"
  add_foreign_key "chat_conversations", "business_profiles"
  add_foreign_key "chat_messages", "accounts", column: "sender_account_id"
  add_foreign_key "chat_messages", "chat_conversations"
  add_foreign_key "chat_messages", "chat_sessions"
  add_foreign_key "chat_sessions", "accounts", column: "customer_account_id"
  add_foreign_key "chat_sessions", "business_profiles"
  add_foreign_key "chat_sessions", "chat_conversations"
  add_foreign_key "device_installations", "accounts"
  add_foreign_key "favorites", "accounts"
  add_foreign_key "favorites", "business_profiles"
  add_foreign_key "notifications", "accounts", column: "actor_account_id"
  add_foreign_key "notifications", "accounts", column: "recipient_account_id"
  add_foreign_key "reviews", "accounts"
  add_foreign_key "reviews", "business_profiles"
  add_foreign_key "schedules", "business_profiles"
  add_foreign_key "wallet_transactions", "accounts"
  add_foreign_key "wallet_transactions", "chat_sessions"
end
