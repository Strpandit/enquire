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
      token = request.params[:token].presence || authorization_token
      reject_unauthorized_connection if token.blank?

      payload = JsonWebToken.decode(token)
      Account.find(payload.fetch("account_id"))
    rescue JWT::DecodeError, JWT::VerificationError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound, KeyError
      reject_unauthorized_connection
    end

    def authorization_token
      request.headers["Authorization"]&.split&.last
    end
  end
end
