module Calls
  class HistoryService
    class Error < StandardError; end

    def self.initiate_call(caller:, receiver:, call_type:, channel_name:)
      normalized_type = (call_type.to_s == "audio" ? "voice" : call_type.to_s)
      business_profile = receiver.business_profile || BusinessProfile.find_by(account_id: receiver.id)

      rate_cents = if business_profile && normalized_type == "voice"
                     business_profile.call_price_cents
      elsif business_profile && normalized_type == "video"
                     business_profile.v_call_price_cents
      else
                     0
      end

      if rate_cents > 0 && caller.wallet_balance_cents < rate_cents
        raise Error, "Insufficient wallet balance to start call (Requires minimum ₹#{rate_cents / 100.0}/min)"
      end

      call_record = CallHistory.create!(
        caller_account: caller,
        receiver_account: receiver,
        call_type: normalized_type,
        channel_name: channel_name,
        status: :initiated,
        metadata: { billed_minutes: 0, rate_per_minute_cents: rate_cents }
      )

      ExpireCallHistoryJob.set(wait_until: CallHistory::REQUEST_TIMEOUT.from_now).perform_later(call_record.id)

      payload = {
        call_history_id: call_record.id,
        channel_name: channel_name,
        call_type: normalized_type,
        caller_name: caller.full_name,
        caller_account_id: caller.id,
        receiver_account_id: receiver.id,
        event: "incoming_call"
      }

      Notifications::Creator.call(
        recipient: receiver,
        actor: caller,
        notifiable: call_record,
        notification_type: "incoming_call",
        title: "Incoming #{normalized_type == 'voice' ? 'Voice' : 'Video'} Call",
        body: "#{caller.full_name} is calling you...",
        payload: payload
      )

      Notifications::Broadcaster.broadcast_payload(
        receiver.id,
        {
          type: "call_history",
          event: "incoming_call",
          call: CallHistoryBlueprint.render_as_hash(call_record)
        }
      )

      ActivityLogger.log(
        account: caller,
        event: "#{normalized_type.upcase}_CALL_INITIATED",
        title: "Initiated #{normalized_type == 'voice' ? 'voice call' : 'video meeting'} to #{receiver.full_name}"
      )

      call_record
    end

    def self.accept_call!(history:, account:)
      raise Error, "Call is not in ringing/initiated status" unless history.initiated?
      raise Error, "Only the call receiver can accept this call" unless history.receiver_account_id == account.id

      business_profile = BusinessProfile.find_by(account_id: history.receiver_account_id) || BusinessProfile.find_by(account_id: history.caller_account_id)
      rate_cents = (history.metadata || {})["rate_per_minute_cents"].to_i
      if rate_cents.zero? && business_profile
        rate_cents = history.voice? ? business_profile.call_price_cents : business_profile.v_call_price_cents
      end

      customer_acc = (business_profile && history.caller_account_id == business_profile.account_id) ? history.receiver_account : history.caller_account
      expert_acc = business_profile ? business_profile.account : history.receiver_account

      if rate_cents > 0 && customer_acc.wallet_balance_cents < rate_cents
        history.update!(status: :declined, ended_at: Time.current, end_reason: "insufficient_balance")
        raise Error, "Customer has insufficient balance to accept call"
      end

      ActiveRecord::Base.transaction do
        history.update!(
          status: :active,
          started_at: Time.current,
          metadata: (history.metadata || {}).merge("billed_minutes" => 1, "rate_per_minute_cents" => rate_cents)
        )

        if rate_cents > 0
          charge_minute!(history: history, customer: customer_acc, expert: expert_acc, minutes: 1, rate_cents: rate_cents)
        end
      end

      Notifications::Broadcaster.broadcast_payload(
        history.caller_account_id,
        {
          type: "call_history",
          event: "call_accepted",
          call: CallHistoryBlueprint.render_as_hash(history)
        }
      )

      history
    end

    def self.decline_call!(history:, account:)
      raise Error, "Call cannot be declined" if history.ended?

      history.update!(status: :declined, ended_at: Time.current, end_reason: "declined_by_receiver")

      Notifications::Broadcaster.broadcast_payload(
        history.caller_account_id,
        {
          type: "call_history",
          event: "call_declined",
          call: CallHistoryBlueprint.render_as_hash(history)
        }
      )

      Notifications::Creator.call(
        recipient: history.caller_account,
        actor: account,
        notifiable: history,
        notification_type: "call_declined",
        title: "Call Declined",
        body: "#{account.full_name} declined your call.",
        payload: { call_history_id: history.id, event: "call_declined" }
      )

      history
    end

    def self.sync_call_billing!(history:, duration_seconds:)
      return history unless history.active?

      duration_sec = duration_seconds.to_i
      needed_minutes = (duration_sec / 60.0).ceil
      needed_minutes = 1 if needed_minutes.zero?

      current_billed = (history.metadata || {})["billed_minutes"].to_i
      new_minutes_to_charge = needed_minutes - current_billed

      return history if new_minutes_to_charge <= 0

      business_profile = BusinessProfile.find_by(account_id: history.receiver_account_id) || BusinessProfile.find_by(account_id: history.caller_account_id)
      rate_cents = (history.metadata || {})["rate_per_minute_cents"].to_i
      if rate_cents.zero? && business_profile
        rate_cents = history.voice? ? business_profile.call_price_cents : business_profile.v_call_price_cents
      end

      customer_acc = (business_profile && history.caller_account_id == business_profile.account_id) ? history.receiver_account : history.caller_account
      expert_acc = business_profile ? business_profile.account : history.receiver_account

      cost_cents = new_minutes_to_charge * rate_cents

      if rate_cents > 0 && customer_acc.wallet_balance_cents < cost_cents
        finish_call!(history: history, duration_seconds: duration_sec, end_reason: "insufficient_balance")
        raise Error, "Call ended due to insufficient wallet balance"
      end

      ActiveRecord::Base.transaction do
        if cost_cents > 0
          charge_minute!(history: history, customer: customer_acc, expert: expert_acc, minutes: new_minutes_to_charge, rate_cents: rate_cents)
        end

        history.update!(
          metadata: (history.metadata || {}).merge("billed_minutes" => current_billed + new_minutes_to_charge)
        )
      end

      history
    end

    def self.finish_call!(history:, duration_seconds: 0, end_reason: nil)
      return history if history.ended?

      normalized_type = (history.video? ? "video" : "voice")
      business_profile = BusinessProfile.find_by(account_id: history.receiver_account_id) || BusinessProfile.find_by(account_id: history.caller_account_id)

      duration_sec = duration_seconds.to_i
      history.update!(
        status: :ended,
        duration_seconds: duration_sec,
        ended_at: Time.current,
        end_reason: end_reason || "ended_by_user"
      )

      Notifications::Broadcaster.broadcast_payload(
        history.caller_account_id == history.receiver_account_id ? history.caller_account_id : history.receiver_account_id,
        {
          type: "call_history",
          event: "call_ended",
          call: CallHistoryBlueprint.render_as_hash(history)
        }
      )

      ActivityLogger.log(
        account: history.caller_account,
        event: "#{normalized_type.upcase}_CALL_ENDED",
        title: "Ended #{normalized_type == 'voice' ? 'voice call' : 'video meeting'} with #{history.receiver_account.full_name} (Duration: #{history.duration_formatted})"
      )
      ActivityLogger.log(
        account: history.receiver_account,
        event: "#{normalized_type.upcase}_CALL_ENDED",
        title: "Completed #{normalized_type == 'voice' ? 'voice call' : 'video meeting'} with #{history.caller_account.full_name} (Duration: #{history.duration_formatted})"
      )

      history
    end

    def self.start_call(caller:, receiver:, call_type:, channel_name:)
      initiate_call(caller: caller, receiver: receiver, call_type: call_type, channel_name: channel_name)
    end

    private

    def self.charge_minute!(history:, customer:, expert:, minutes:, rate_cents:)
      amount_cents = minutes * rate_cents
      platform_fee_cents = amount_cents - (amount_cents * 0.8).to_i
      expert_earning_cents = amount_cents - platform_fee_cents

      Wallets::LedgerService.debit!(
        account: customer,
        amount_cents: amount_cents,
        description: "#{history.call_type.to_s.capitalize} call charge",
        metadata: { call_history_id: history.id, billed_minutes: minutes }
      )

      Wallets::LedgerService.credit_earnings!(
        account: expert,
        amount_cents: expert_earning_cents,
        description: "#{history.call_type.to_s.capitalize} call earnings",
        metadata: { call_history_id: history.id, earning_type: "call", billed_minutes: minutes, platform_fee_cents: platform_fee_cents, platform_fee_percent: 20 }
      )

      history.update!(amount_charged_cents: history.amount_charged_cents + amount_cents)
    end
  end
end
