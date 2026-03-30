module Wallets
  class LedgerService
    class Error < StandardError; end

    def self.debit!(account:, amount_cents:, description:, chat_session: nil, metadata: {}, reference: nil)
      new(
        account: account,
        amount_cents: amount_cents,
        transaction_type: :debit,
        description: description,
        chat_session: chat_session,
        metadata: metadata,
        reference: reference
      ).apply!
    end

    def self.credit!(account:, amount_cents:, description:, chat_session: nil, metadata: {}, reference: nil)
      new(
        account: account,
        amount_cents: amount_cents,
        transaction_type: :credit,
        description: description,
        chat_session: chat_session,
        metadata: metadata,
        reference: reference
      ).apply!
    end

    def initialize(account:, amount_cents:, transaction_type:, description:, chat_session:, metadata:, reference:)
      @account = account
      @amount_cents = amount_cents.to_i
      @transaction_type = transaction_type.to_s
      @description = description
      @chat_session = chat_session
      @metadata = metadata
      @reference = reference
    end

    def apply!
      raise Error, "Amount must be positive" unless amount_cents.positive?

      account.with_lock do
        updated_balance = transaction_type == "debit" ? account.wallet_balance_cents - amount_cents : account.wallet_balance_cents + amount_cents
        raise Error, "Insufficient wallet balance" if updated_balance.negative?

        account.update!(wallet_balance_cents: updated_balance)
        account.wallet_transactions.create!(
          chat_session: chat_session,
          transaction_type: transaction_type,
          amount_cents: amount_cents,
          balance_after_cents: updated_balance,
          entry_type: chat_session.present? ? "chat" : "manual",
          reference_type: reference&.class&.name,
          reference_id: reference&.id,
          description: description,
          metadata: metadata
        )
      end
    end

    private

    attr_reader :account, :amount_cents, :transaction_type, :description, :chat_session, :metadata, :reference
  end
end
