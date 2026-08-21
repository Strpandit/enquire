class CallHistoryBlueprint < Blueprinter::Base
  fields :id, :call_type, :channel_name, :duration_seconds, :status, :amount_charged_cents,
         :started_at, :ended_at, :end_reason, :created_at

  association :caller_account, blueprint: AccountBlueprint
  association :receiver_account, blueprint: AccountBlueprint

  view :list do
    fields :id, :call_type, :status, :duration_seconds, :amount_charged_cents, :started_at, :ended_at, :created_at

    # Include minimal account info so the history list can show names
    field :caller_account do |history|
      acc = history.caller_account
      { id: acc.id, full_name: acc.full_name, is_verified: acc.is_verified? }
    end

    field :receiver_account do |history|
      acc = history.receiver_account
      { id: acc.id, full_name: acc.full_name, is_verified: acc.is_verified? }
    end
  end
end
