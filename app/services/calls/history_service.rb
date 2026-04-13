module Calls
  class HistoryService
    class Error < StandardError; end

    def self.create_history(caller:, receiver:, call_type:, channel_name:, business_profile:, duration_seconds: 0, end_reason: nil)
      amount_cents = if business_profile && call_type == "voice"
                       business_profile.chat_price_cents
                     elsif business_profile && call_type == "video"
                       business_profile.v_call_price_cents
                     else
                       0
                     end

      ActiveRecord::Base.transaction do
        history = CallHistory.create!(
          caller_account: caller,
          receiver_account: receiver,
          call_type: call_type,
          channel_name: channel_name,
          status: :ended,
          duration_seconds: duration_seconds,
          amount_charged_cents: amount_cents,
          ended_at: Time.current,
          end_reason: end_reason
        )

        if amount_cents > 0
          Wallets::LedgerService.debit!(
            account: caller,
            amount_cents: amount_cents,
            description: "#{call_type} call charge with #{receiver.full_name}",
            metadata: { call_history_id: history.id }
          )

          Wallets::LedgerService.credit!(
            account: receiver,
            amount_cents: (amount_cents * 0.8).to_i,
            description: "Earnings from #{call_type} call with #{caller.full_name}",
            metadata: { call_history_id: history.id, earning_type: "call" }
          )
        end

        history
      end
    end

    def self.start_call(caller:, receiver:, call_type:, channel_name:)
      CallHistory.create!(
        caller_account: caller,
        receiver_account: receiver,
        call_type: call_type,
        channel_name: channel_name,
        status: :active,
        started_at: Time.current
      )
    end
  end
end
