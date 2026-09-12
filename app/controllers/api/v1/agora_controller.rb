module Api
  module V1
    class AgoraController < BaseController
      def token
        channel_name = params.require(:channel_name)
        uid = params.require(:uid)
        role = params.fetch(:role, "publisher")

        history = CallHistory
          .where(channel_name: channel_name, status: [ CallHistory.statuses[:initiated], CallHistory.statuses[:active] ])
          .where("caller_account_id = :id OR receiver_account_id = :id", id: current_account.id)
          .order(created_at: :desc)
          .first

        raise ActionController::ParameterMissing, "You are not a participant in this call" unless history

        render json: {
          app_id: ENV.fetch("AGORA_APP_ID"),
          token: Agora::TokenService.generate(channel_name: channel_name, uid: uid, role: role),
          channel_name: channel_name,
          uid: uid
        }, status: :ok
      end
    end
  end
end
