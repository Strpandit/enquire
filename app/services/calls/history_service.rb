module Calls
  class HistoryService
    class Error < StandardError; end

    def self.initiate_call(caller:, receiver:, call_type:, channel_name:)
      normalized_type = (call_type.to_s == "audio" ? "voice" : call_type.to_s)
      business_profile = receiver.business_profile || BusinessProfile.find_by(account_id: receiver.id)

      rate = if business_profile && normalized_type == "voice"
               business_profile.call_price
      elsif business_profile && normalized_type == "video"
               business_profile.v_call_price
      else
               0
      end
      rate = rate.to_i

      raise Error, "You cannot call your own business profile" if caller.id == receiver.id

      if rate > 0 && caller.wallet_balance < rate
        raise Error, "Insufficient wallet balance to start call (Requires minimum ₹#{rate}/min)"
      end

      call_record = CallHistory.create!(
        caller_account: caller,
        receiver_account: receiver,
        call_type: normalized_type,
        channel_name: channel_name,
        status: :initiated,
        metadata: { billed_minutes: 0, rate_per_minute: rate }
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

      insufficient_balance = false

      history.with_lock do
        break unless history.initiated?

        business_profile = BusinessProfile.find_by(account_id: history.receiver_account_id) || BusinessProfile.find_by(account_id: history.caller_account_id)
        rate = (history.metadata || {})["rate_per_minute"].to_i
        if rate.zero? && business_profile
          rate = (history.voice? ? business_profile.call_price : business_profile.v_call_price).to_i
        end

        customer_acc = (business_profile && history.caller_account_id == business_profile.account_id) ? history.receiver_account : history.caller_account
        expert_acc = business_profile ? business_profile.account : history.receiver_account

        if rate > 0 && customer_acc.wallet_balance < rate
          # Persist the decline first — signal after the lock/transaction
          # commits so this update doesn't get rolled back by the raise.
          history.update!(status: :declined, ended_at: Time.current, end_reason: "insufficient_balance")
          insufficient_balance = true
          break
        end

        history.update!(
          status: :active,
          started_at: Time.current,
          metadata: (history.metadata || {}).merge("billed_minutes" => 1, "rate_per_minute" => rate)
        )

        charge_minute!(history: history, customer: customer_acc, expert: expert_acc, minutes: 1, rate: rate) if rate > 0
      end

      raise Error, "Customer has insufficient balance to accept call" if insufficient_balance
      raise Error, "Call is not in ringing/initiated status" unless history.active?

      Notifications::Broadcaster.broadcast_payload(
        history.caller_account_id,
        {
          type: "call_history",
          event: "call_accepted",
          call_history_id: history.id,
          call: CallHistoryBlueprint.render_as_hash(history)
        }
      )

      # Mark incoming call notification as read on accept
      Notification.where(notifiable: history).update_all(read_at: Time.current)

      history
    end

    def self.decline_call!(history:, account:)
      raise Error, "Call cannot be declined" if history.ended?

      history.update!(status: :declined, ended_at: Time.current, end_reason: "declined_by_receiver")

      # Mark any incoming_call notifications as read
      Notification.where(notifiable: history).update_all(read_at: Time.current)

      [history.caller_account_id, history.receiver_account_id].compact.uniq.each do |target_acc_id|
        Notifications::Broadcaster.broadcast_payload(
          target_acc_id,
          {
            type: "call_history",
            event: "call_declined",
            call_history_id: history.id,
            call: CallHistoryBlueprint.render_as_hash(history)
          }
        )
      end

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

    # `duration_seconds` is accepted for backward compatibility but is NOT
    # trusted for billing — a modified client could report an arbitrarily
    # small (or zero) duration to avoid being charged. Elapsed time is
    # always computed server-side from `started_at`.
    def self.sync_call_billing!(history:, duration_seconds: nil)
      return history unless history.active?

      insufficient_balance = false
      duration_sec = 0

      history.with_lock do
        break unless history.active?

        duration_sec = history.started_at ? (Time.current - history.started_at).to_i : duration_seconds.to_i
        needed_minutes = (duration_sec / 60.0).ceil
        needed_minutes = 1 if needed_minutes.zero?

        current_billed = (history.metadata || {})["billed_minutes"].to_i
        new_minutes_to_charge = needed_minutes - current_billed

        next if new_minutes_to_charge <= 0

        business_profile = BusinessProfile.find_by(account_id: history.receiver_account_id) || BusinessProfile.find_by(account_id: history.caller_account_id)
        rate = (history.metadata || {})["rate_per_minute"].to_i
        if rate.zero? && business_profile
          rate = (history.voice? ? business_profile.call_price : business_profile.v_call_price).to_i
        end

        customer_acc = (business_profile && history.caller_account_id == business_profile.account_id) ? history.receiver_account : history.caller_account
        expert_acc = business_profile ? business_profile.account : history.receiver_account

        cost = new_minutes_to_charge * rate

        if rate > 0 && customer_acc.wallet_balance < cost
          insufficient_balance = true
          break
        end

        charge_minute!(history: history, customer: customer_acc, expert: expert_acc, minutes: new_minutes_to_charge, rate: rate) if cost > 0

        history.update!(
          metadata: (history.metadata || {}).merge("billed_minutes" => current_billed + new_minutes_to_charge)
        )
      end

      if insufficient_balance
        finish_call!(history: history, duration_seconds: duration_sec, end_reason: "insufficient_balance")
        raise Error, "Call ended due to insufficient wallet balance"
      end

      history
    end

    def self.finish_call!(history:, duration_seconds: 0, end_reason: nil)
      return history if history.ended? || history.declined? || history.missed? || history.expired?

      duration_sec = history.started_at ? (Time.current - history.started_at).to_i : duration_seconds.to_i
      normalized_type = (history.video? ? "video" : "voice")

      already_ended = false
      history.with_lock do
        if history.ended? || history.declined? || history.missed? || history.expired?
          already_ended = true
          break
        end

        status_to_set = if ["declined_by_receiver", "call_declined", "declined"].include?(end_reason.to_s)
                          :declined
                        elsif ["no_answer", "unanswered", "call_missed", "missed"].include?(end_reason.to_s)
                          :missed
                        else
                          :ended
                        end

        history.update!(
          status: status_to_set,
          duration_seconds: duration_sec,
          ended_at: Time.current,
          end_reason: end_reason || "ended_by_user"
        )
      end
      return history if already_ended

      Notification.where(notifiable: history).update_all(read_at: Time.current)

      [history.caller_account_id, history.receiver_account_id].compact.uniq.each do |target_acc_id|
        Notifications::Broadcaster.broadcast_payload(
          target_acc_id,
          {
            type: "call_history",
            event: "call_ended",
            call_history_id: history.id,
            call: CallHistoryBlueprint.render_as_hash(history)
          }
        )
      end

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

    def self.charge_minute!(history:, customer:, expert:, minutes:, rate:)
      amount = minutes * rate
      platform_fee = (amount * 20) / 100
      expert_earning = amount - platform_fee

      Wallets::LedgerService.debit!(
        account: customer,
        amount: amount,
        description: "#{history.call_type.to_s.capitalize} call charge",
        metadata: { call_history_id: history.id, billed_minutes: minutes }
      )

      Wallets::LedgerService.credit_earnings!(
        account: expert,
        amount: expert_earning,
        description: "#{history.call_type.to_s.capitalize} call earnings",
        metadata: { call_history_id: history.id, earning_type: "call", billed_minutes: minutes, platform_fee: platform_fee, platform_fee_percent: 20 }
      )

      CallHistory.update_counters(history.id, amount_charged: amount)
      history.reload
    end
  end
end
