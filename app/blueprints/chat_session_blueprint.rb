class ChatSessionBlueprint < Blueprinter::Base
  identifier :id

  fields :chat_conversation_id, :customer_account_id, :business_profile_id, :status, :price_per_minute_cents,
         :requested_at, :started_at, :ended_at, :last_billed_at, :billable_seconds, :billed_minutes,
         :total_amount_cents, :end_reason
end
