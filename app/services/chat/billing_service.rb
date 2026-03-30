module Chat
  class BillingService
    class Error < StandardError; end

    def initialize(chat_session)
      @chat_session = chat_session
    end

    def sync!
      return chat_session unless chat_session.active?

      now = Time.current
      from_time = chat_session.last_billed_at || chat_session.started_at || now
      elapsed_seconds = [now.to_i - from_time.to_i, 0].max
      started_new_minutes = elapsed_seconds / 60
      return chat_session if started_new_minutes.zero?

      charge_for_started_minutes!(started_new_minutes, from_time, now)
      chat_session.reload
    end

    def charge_upfront_first_minute!
      return chat_session unless chat_session.active?
      return chat_session if chat_session.billed_minutes.positive?

      charge_for_started_minutes!(1, chat_session.started_at || Time.current, Time.current)
      chat_session.reload
    end

    private

    attr_reader :chat_session

    def charge_for_started_minutes!(started_minutes, from_time, now)
      customer = chat_session.customer_account
      business_owner = chat_session.business_profile.account
      affordable_minutes = customer.wallet_balance_cents / chat_session.price_per_minute_cents
      chargeable_minutes = [started_minutes, affordable_minutes].min

      if chargeable_minutes.zero?
        end_for_insufficient_balance!(now)
        return
      end

      chargeable_cents = chargeable_minutes * chat_session.price_per_minute_cents
      billed_through = from_time + (chargeable_minutes * 60)

      ActiveRecord::Base.transaction do
        Wallets::LedgerService.debit!(
          account: customer,
          amount_cents: chargeable_cents,
          description: "Chat charge for session ##{chat_session.id}",
          chat_session: chat_session,
          metadata: { billed_minutes: chargeable_minutes, billing_mode: "started_minute" },
          reference: chat_session
        )
        Wallets::LedgerService.credit!(
          account: business_owner,
          amount_cents: chargeable_cents,
          description: "Chat earning for session ##{chat_session.id}",
          chat_session: chat_session,
          metadata: { billed_minutes: chargeable_minutes, billing_mode: "started_minute" },
          reference: chat_session
        )

        chat_session.update!(
          billed_minutes: chat_session.billed_minutes + chargeable_minutes,
          billable_seconds: chat_session.billable_seconds + (chargeable_minutes * 60),
          total_amount_cents: chat_session.total_amount_cents + chargeable_cents,
          last_billed_at: billed_through
        )
      end

      if chargeable_minutes < started_minutes
        end_for_insufficient_balance!(now)
      else
        Chat::Broadcaster.broadcast_to_conversation(chat_session.chat_conversation, session_payload("billing_synced"))
      end
    end

    def end_for_insufficient_balance!(now)
      chat_session.update!(
        status: :ended,
        ended_at: now,
        end_reason: "insufficient_balance",
        last_billed_at: now
      )
      Chat::Broadcaster.broadcast_to_conversation(chat_session.chat_conversation, session_payload("session_ended"))
    end

    def session_payload(event)
      {
        type: "chat_session",
        event: event,
        session: ChatSessionBlueprint.render_as_hash(chat_session.reload)
      }
    end
  end
end
