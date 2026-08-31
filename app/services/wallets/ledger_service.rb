module Wallets
  class LedgerService
    class Error < StandardError; end

    Result = Struct.new(:transaction, :already_applied) do
      def already_applied?
        already_applied
      end
    end

    def self.debit!(account:, amount:, description:, chat_session: nil, metadata: {}, reference: nil, idempotency_key: nil)
      new(
        account: account,
        amount: amount,
        transaction_type: :debit,
        description: description,
        chat_session: chat_session,
        metadata: metadata,
        reference: reference,
        idempotency_key: idempotency_key
      ).apply!
    end

    def self.credit!(account:, amount:, description:, chat_session: nil, metadata: {}, reference: nil, idempotency_key: nil)
      new(
        account: account,
        amount: amount,
        transaction_type: :credit,
        description: description,
        chat_session: chat_session,
        metadata: metadata,
        reference: reference,
        target_wallet: :cash,
        idempotency_key: idempotency_key
      ).apply!
    end

    def self.credit_earnings!(account:, amount:, description:, chat_session: nil, metadata: {}, reference: nil, idempotency_key: nil)
      new(
        account: account,
        amount: amount,
        transaction_type: :credit,
        description: description,
        chat_session: chat_session,
        metadata: metadata,
        reference: reference,
        target_wallet: :earnings,
        idempotency_key: idempotency_key
      ).apply!
    end

    def initialize(account:, amount:, transaction_type:, description:, chat_session:, metadata:, reference:, idempotency_key:, target_wallet: :cash)
      @account = account
      @amount = amount.to_i
      @transaction_type = transaction_type.to_s
      @description = description
      @chat_session = chat_session
      @metadata = metadata
      @reference = reference
      @target_wallet = target_wallet
      @idempotency_key = idempotency_key
    end

    def apply!
      raise Error, "Amount must be positive" unless amount.positive?

      account.with_lock do
        if idempotency_key.present?
          existing = account.wallet_transactions.find_by(idempotency_key: idempotency_key)
          return Result.new(existing, true) if existing
        end

        if target_wallet == :earnings
          updated_balance = account.earnings_balance + amount
          account.update!(earnings_balance: updated_balance)
          txn = account.wallet_transactions.create!(
            chat_session: chat_session,
            transaction_type: "credit",
            amount: amount,
            balance_after: updated_balance,
            entry_type: "earnings",
            reference_type: reference&.class&.name,
            reference_id: reference&.id,
            description: description,
            metadata: metadata.merge(target_wallet: "earnings"),
            idempotency_key: idempotency_key
          )
        else
          updated_balance = transaction_type == "debit" ? account.wallet_balance - amount : account.wallet_balance + amount
          raise Error, "Insufficient wallet balance" if updated_balance.negative?

          account.update!(wallet_balance: updated_balance)
          txn = account.wallet_transactions.create!(
            chat_session: chat_session,
            transaction_type: transaction_type,
            amount: amount,
            balance_after: updated_balance,
            entry_type: chat_session.present? ? "chat" : "manual",
            reference_type: reference&.class&.name,
            reference_id: reference&.id,
            description: description,
            metadata: metadata,
            idempotency_key: idempotency_key
          )
        end

        Result.new(txn, false)
      end
    rescue ActiveRecord::RecordNotUnique
      Result.new(account.wallet_transactions.find_by(idempotency_key: idempotency_key), true)
    end

    private

    attr_reader :account, :amount, :transaction_type, :description, :chat_session, :metadata, :reference, :target_wallet, :idempotency_key
  end
end
