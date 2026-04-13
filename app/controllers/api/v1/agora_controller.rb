module Api
  module V1
    class AgoraController < BaseController
      def token
        channel_name = params.require(:channel_name)
        uid = params.require(:uid)
        role = params.fetch(:role, "publisher")

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
