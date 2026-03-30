module Api
  module V1
    class DeviceInstallationsController < BaseController
      def create
        installation = DeviceInstallation.find_or_initialize_by(device_token: device_installation_params[:device_token])
        installation.account = current_account
        installation.assign_attributes(device_installation_params.merge(active: true, last_seen_at: Time.current))
        installation.save!

        render json: {
          message: "Device registered successfully",
          device_installation: DeviceInstallationBlueprint.render_as_hash(installation)
        }, status: :ok
      end

      def destroy
        installation = current_account.device_installations.find(params[:id])
        installation.update!(active: false, last_seen_at: Time.current)

        render json: { message: "Device unregistered successfully" }, status: :ok
      end

      private

      def device_installation_params
        params.require(:device_installation).permit(:platform, :device_token, :device_id, metadata: {})
      end
    end
  end
end
