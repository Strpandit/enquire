module Wallets
  # Collapses per-minute ledger rows (one chat/call session = many rows) into one
  # entry per session so the wallet screen can show a single professional line
  # with total, duration and a minute-wise breakdown. Read-only: never touches
  # the underlying wallet_transactions rows.
  class GroupedHistory
    GROUP_KEY_SQL = <<~SQL.squish.freeze
      (CASE
         WHEN chat_session_id IS NOT NULL THEN 'chat-' || chat_session_id::text
         WHEN metadata->>'call_history_id' IS NOT NULL THEN 'call-' || (metadata->>'call_history_id')
         ELSE 'txn-' || id::text
       END) || '-' || transaction_type::text
    SQL

    Page = Struct.new(:groups, :current_page, :next_page, :per_page)

    def initialize(account:, page:, per_page:)
      @account = account
      @page = [ page.to_i, 1 ].max
      @per_page = per_page
    end

    def call
      keys = page_keys
      has_next = keys.size > per_page
      keys = keys.first(per_page)
      return Page.new([], page, nil, per_page) if keys.empty?

      rows = account.wallet_transactions
                    .select("wallet_transactions.*, #{GROUP_KEY_SQL} AS group_key")
                    .where("#{GROUP_KEY_SQL} IN (?)", keys)
                    .order(:created_at, :id)
                    .to_a

      grouped = rows.group_by(&:group_key)
      sessions = ChatSession.includes(:business_profile, customer_account: :business_profile)
                            .where(id: rows.filter_map(&:chat_session_id).uniq).index_by(&:id)
      calls = CallHistory.includes(caller_account: :business_profile, receiver_account: :business_profile)
                         .where(id: rows.filter_map { |r| call_history_id(r) }.uniq).index_by(&:id)

      groups = keys.filter_map do |key|
        txns = grouped[key]
        next if txns.blank?

        build_group(key, txns, sessions, calls)
      end

      Page.new(groups, page, has_next ? page + 1 : nil, per_page)
    end

    private

    attr_reader :account, :page, :per_page

    def page_keys
      account.wallet_transactions
             .group(Arel.sql(GROUP_KEY_SQL))
             .order(Arel.sql("MAX(created_at) DESC, MAX(id) DESC"))
             .offset((page - 1) * per_page)
             .limit(per_page + 1)
             .pluck(Arel.sql(GROUP_KEY_SQL))
    end

    def call_history_id(txn)
      id = (txn.metadata || {})["call_history_id"]
      id.present? ? id.to_i : nil
    end

    def build_group(key, txns, sessions, calls)
      first = txns.first
      last = txns.last
      session = sessions[first.chat_session_id] if first.chat_session_id
      call = calls[call_history_id(first)] if call_history_id(first)

      kind = session ? "chat" : (call ? "call" : "other")
      started_at = first.created_at
      ended_at = last.created_at
      duration_seconds = nil
      counterparty = nil
      rate = nil
      status = nil
      call_type = nil

      if session
        started_at = session.started_at || started_at
        ended_at = session.active? ? nil : (session.ended_at || ended_at)
        rate = session.price_per_minute
        status = session.active? ? "ongoing" : "completed"
        other = first.transaction_type == "debit" ? session.business_profile&.account : session.customer_account
        expert_side = other && other.id == session.business_profile&.account_id
        counterparty = display_name(other, expert_side ? session.business_profile : nil)
      elsif call
        started_at = call.started_at || started_at
        ended_at = call.active? ? nil : (call.ended_at || ended_at)
        duration_seconds = call.duration_seconds if call.ended?
        rate = (call.metadata || {})["rate_per_minute"].presence&.to_i
        call_type = call.call_type
        status = call.active? ? "ongoing" : "completed"
        other = call.caller_account_id == account.id ? call.receiver_account : call.caller_account
        counterparty = display_name(other, other&.business_profile)
      end

      duration_seconds ||= [ (ended_at - started_at).to_i, 0 ].max if ended_at && started_at

      billed_minutes = txns.sum { |t| (t.metadata || {})["billed_minutes"].to_i }
      billed_minutes = txns.size if billed_minutes.zero? && kind != "other"
      platform_fee = txns.sum { |t| (t.metadata || {})["platform_fee"].to_i }

      {
        key: key,
        kind: kind,
        call_type: call_type,
        transaction_type: first.transaction_type,
        entry_type: first.entry_type,
        description: last.description,
        amount: txns.sum(&:amount),
        platform_fee: platform_fee,
        billed_minutes: billed_minutes,
        rate_per_minute: rate,
        counterparty_name: counterparty,
        status: status,
        started_at: started_at,
        ended_at: ended_at,
        duration_seconds: duration_seconds,
        created_at: last.created_at,
        balance_after: last.balance_after,
        transactions: txns.map do |t|
          {
            id: t.id,
            amount: t.amount,
            balance_after: t.balance_after,
            billed_minutes: (t.metadata || {})["billed_minutes"].to_i,
            created_at: t.created_at
          }
        end
      }
    end

    def display_name(acct, profile)
      return nil unless acct

      profile&.business_name.presence || acct.full_name
    end
  end
end
