module Calls
  class HistoryService
    class Error < StandardError; end

    def self.finish_call!(history:, duration_seconds: 0, end_reason: nil)
      normalized_type = (history.call_type.to_s == "audio" ? "voice" : history.call_type.to_s)
      business_profile = history.receiver_account&.business_profile

      rate_per_minute_cents = if business_profile && normalized_type == "voice"
                                business_profile.call_price_cents
                              elsif business_profile && normalized_type == "video"
                                business_profile.v_call_price_cents
                              else
                                0
                              end

      duration_sec = duration_seconds.to_i
      billed_minutes = (duration_sec / 60.0).ceil
      amount_cents = billed_minutes * rate_per_minute_cents

      ActiveRecord::Base.transaction do
        history.update!(
          status: :ended,
          duration_seconds: duration_sec,
          amount_charged_cents: amount_cents,
          ended_at: Time.current,
          end_reason: end_reason
        )

        if amount_cents > 0
          Wallets::LedgerService.debit!(
            account: history.caller_account,
            amount_cents: amount_cents,
            description: "#{normalized_type.capitalize} call charge with #{history.receiver_account.full_name}",
            metadata: { call_history_id: history.id, duration_seconds: duration_sec, billed_minutes: billed_minutes }
          )

          Wallets::LedgerService.credit!(
            account: history.receiver_account,
            amount_cents: (amount_cents * 0.8).to_i,
            description: "Earnings from #{normalized_type} call with #{history.caller_account.full_name}",
            metadata: { call_history_id: history.id, earning_type: "call", duration_seconds: duration_sec, billed_minutes: billed_minutes }
          )
        end

        history
      end
    end

    def self.start_call(caller:, receiver:, call_type:, channel_name:)
      normalized_type = (call_type.to_s == "audio" ? "voice" : call_type.to_s)
      CallHistory.create!(
        caller_account: caller,
        receiver_account: receiver,
        call_type: normalized_type,
        channel_name: channel_name,
        status: :active,
        started_at: Time.current
      )
    end
  end
end

