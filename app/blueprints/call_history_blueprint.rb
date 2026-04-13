class CallHistoryBlueprint < Blueprinter::Base
  fields :id, :call_type, :channel_name, :duration_seconds, :status, :amount_charged_cents,
         :started_at, :ended_at, :end_reason, :created_at

  association :caller_account, blueprint: AccountBlueprint
  association :receiver_account, blueprint: AccountBlueprint

  view :list do
    fields :id, :call_type, :status, :duration_seconds, :amount_charged_cents, :started_at, :ended_at
  end
end
