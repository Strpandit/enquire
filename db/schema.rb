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

ActiveRecord::Schema[8.0].define(version: 2026_09_12_080000) do
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
    t.integer "wallet_balance", default: 0, null: false
    t.string "uid"
    t.datetime "last_seen_at"
    t.integer "earnings_balance", default: 0, null: false
    t.index "lower((email)::text)", name: "index_accounts_on_lower_email", unique: true
    t.index "lower((username)::text)", name: "index_accounts_on_lower_username", unique: true, where: "(username IS NOT NULL)"
    t.index ["earnings_balance"], name: "index_accounts_on_earnings_balance"
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

  create_table "activity_logs", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "device_id"
    t.string "event", null: false
    t.string "title"
    t.jsonb "metadata", default: {}
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_activity_logs_on_account_id"
    t.index ["device_id"], name: "index_activity_logs_on_device_id"
    t.index ["event"], name: "index_activity_logs_on_event"
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
    t.integer "chat_price"
    t.integer "call_price"
    t.integer "v_call_price"
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
    t.index ["approval_status", "avg_rating", "created_at"], name: "index_business_profiles_on_status_rating_created"
    t.index ["gst_number"], name: "index_business_profiles_on_gst_number", unique: true
    t.index ["share_token"], name: "index_business_profiles_on_share_token", unique: true
  end

  create_table "call_histories", force: :cascade do |t|
    t.bigint "caller_account_id", null: false
    t.bigint "receiver_account_id", null: false
    t.string "call_type", default: "voice", null: false
    t.string "channel_name", null: false
    t.integer "duration_seconds", default: 0, null: false
    t.integer "amount_charged", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.datetime "started_at"
    t.datetime "ended_at"
    t.text "end_reason"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["caller_account_id"], name: "index_call_histories_on_caller_account_id"
    t.index ["created_at"], name: "index_call_histories_on_created_at"
    t.index ["receiver_account_id"], name: "index_call_histories_on_receiver_account_id"
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
    t.text "content"
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
    t.integer "price_per_minute", null: false
    t.datetime "requested_at", null: false
    t.datetime "started_at"
    t.datetime "ended_at"
    t.datetime "last_billed_at"
    t.integer "billable_seconds", default: 0, null: false
    t.integer "billed_minutes", default: 0, null: false
    t.integer "total_amount", default: 0, null: false
    t.string "end_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_profile_id"], name: "index_chat_sessions_on_business_profile_id"
    t.index ["chat_conversation_id", "status"], name: "idx_chat_sessions_on_conversation_and_status"
    t.index ["chat_conversation_id"], name: "idx_unique_open_chat_session_per_conversation", unique: true, where: "(status = ANY (ARRAY[0, 1]))"
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

  create_table "device_sessions", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "device_id"
    t.string "ip_address"
    t.string "network_type"
    t.datetime "login_at"
    t.datetime "last_seen_at"
    t.datetime "logout_at"
    t.string "app_version"
    t.string "android_version"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_device_sessions_on_account_id"
    t.index ["device_id"], name: "index_device_sessions_on_device_id"
  end

  create_table "devices", force: :cascade do |t|
    t.bigint "account_id"
    t.string "device_uuid", null: false
    t.string "manufacturer"
    t.string "model"
    t.string "android_version"
    t.integer "android_api_level"
    t.string "app_version", default: "1.0.0"
    t.integer "app_build", default: 1
    t.string "network_type"
    t.string "last_ip"
    t.string "push_token"
    t.datetime "first_seen_at"
    t.datetime "last_seen_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "device_uuid"], name: "index_devices_on_account_id_and_device_uuid", unique: true
    t.index ["account_id"], name: "index_devices_on_account_id"
    t.index ["device_uuid"], name: "index_devices_on_device_uuid"
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

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.binary "payload", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "channel_hash", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.string "description"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_failure"
    t.text "metadata"
    t.integer "total_jobs", default: 0, null: false
    t.integer "completed_jobs", default: 0, null: false
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "failed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "batch_id"
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "wallet_transactions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "chat_session_id"
    t.integer "transaction_type", null: false
    t.integer "amount", null: false
    t.integer "balance_after", null: false
    t.string "entry_type", null: false
    t.string "reference_type"
    t.bigint "reference_id"
    t.string "description", null: false
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "idempotency_key"
    t.index ["account_id", "created_at"], name: "index_wallet_transactions_on_account_id_and_created_at"
    t.index ["account_id"], name: "index_wallet_transactions_on_account_id"
    t.index ["chat_session_id"], name: "index_wallet_transactions_on_chat_session_id"
    t.index ["idempotency_key"], name: "index_wallet_transactions_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["reference_type", "reference_id"], name: "idx_wallet_transactions_on_reference"
  end

  create_table "withdrawal_requests", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.integer "amount", null: false
    t.string "upi_id", null: false
    t.integer "status", default: 0, null: false
    t.string "withdrawal_id"
    t.string "failure_reason"
    t.datetime "approved_at"
    t.datetime "completed_at"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_withdrawal_requests_on_account_id"
    t.index ["status"], name: "index_withdrawal_requests_on_status"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activity_logs", "accounts"
  add_foreign_key "activity_logs", "devices"
  add_foreign_key "business_profile_categories", "business_profiles"
  add_foreign_key "business_profile_categories", "categories"
  add_foreign_key "business_profiles", "accounts"
  add_foreign_key "call_histories", "accounts", column: "caller_account_id"
  add_foreign_key "call_histories", "accounts", column: "receiver_account_id"
  add_foreign_key "chat_conversations", "accounts", column: "customer_account_id"
  add_foreign_key "chat_conversations", "business_profiles"
  add_foreign_key "chat_messages", "accounts", column: "sender_account_id"
  add_foreign_key "chat_messages", "chat_conversations"
  add_foreign_key "chat_messages", "chat_sessions"
  add_foreign_key "chat_sessions", "accounts", column: "customer_account_id"
  add_foreign_key "chat_sessions", "business_profiles"
  add_foreign_key "chat_sessions", "chat_conversations"
  add_foreign_key "device_installations", "accounts"
  add_foreign_key "device_sessions", "accounts"
  add_foreign_key "device_sessions", "devices"
  add_foreign_key "devices", "accounts"
  add_foreign_key "favorites", "accounts"
  add_foreign_key "favorites", "business_profiles"
  add_foreign_key "notifications", "accounts", column: "actor_account_id"
  add_foreign_key "notifications", "accounts", column: "recipient_account_id"
  add_foreign_key "reviews", "accounts"
  add_foreign_key "reviews", "business_profiles"
  add_foreign_key "schedules", "business_profiles"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "wallet_transactions", "accounts"
  add_foreign_key "wallet_transactions", "chat_sessions"
  add_foreign_key "withdrawal_requests", "accounts"
end
