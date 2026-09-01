module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_account

    def connect
      self.current_account = find_verified_account
      Chat::PresenceService.mark_online!(current_account)
    end

    def disconnect
      Chat::PresenceService.mark_offline!(current_account) if current_account.present?
    end

    private

    def find_verified_account
      if (ticket = request.params[:ticket].presence)
        account_id = Rails.cache.read("cable_ticket:#{ticket}")
        reject_unauthorized_connection if account_id.blank?
        Rails.cache.delete("cable_ticket:#{ticket}")
        return Account.find(account_id)
      end

      token = request.params[:token].presence || authorization_token
      reject_unauthorized_connection if token.blank?

      payload = JsonWebToken.decode(token)
      account = Account.find(payload.fetch("account_id"))
      if payload["pwd"].present? && payload["pwd"] != account.password_token_fingerprint
        reject_unauthorized_connection
      end
      account
    rescue JWT::DecodeError, JWT::VerificationError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound, KeyError
      reject_unauthorized_connection
    end

    def authorization_token
      request.headers["Authorization"]&.split&.last
    end
  end
end
