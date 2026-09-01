module Api
  module V1
    class CableTicketsController < BaseController
      TICKET_TTL = 30.seconds

      def create
        ticket = SecureRandom.urlsafe_base64(32)
        Rails.cache.write("cable_ticket:#{ticket}", current_account.id, expires_in: TICKET_TTL)

        render json: { ticket: ticket, expires_in: TICKET_TTL.to_i }, status: :ok
      end
    end
  end
end
