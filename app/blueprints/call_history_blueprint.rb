class CallHistoryBlueprint < Blueprinter::Base
  fields :id, :call_type, :channel_name, :duration_seconds, :status, :amount_charged,
         :started_at, :ended_at, :end_reason, :created_at

  association :caller_account, blueprint: AccountBlueprint
  association :receiver_account, blueprint: AccountBlueprint

  view :list do
    fields :id, :call_type, :status, :duration_seconds, :amount_charged, :started_at, :ended_at, :end_reason, :created_at

    field :caller_account do |history|
      acc = history.caller_account
      {
        id: acc.id,
        full_name: acc.full_name,
        profile_pic_url: acc.profile_pic_url,
        is_verified: acc.is_verified?
      }
    end

    field :receiver_account do |history|
      acc = history.receiver_account
      {
        id: acc.id,
        full_name: acc.full_name,
        profile_pic_url: acc.profile_pic_url,
        is_verified: acc.is_verified?
      }
    end
  end
end
