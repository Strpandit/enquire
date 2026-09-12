module Api
  module V1
    class DeviceInstallationsController < BaseController
      FAKE_TOKEN_PREFIXES = %w[push_ ExponentPushToken ExpoPushToken fake_ test_ dummy_].freeze
      MIN_TOKEN_LENGTH = 64

      def create
        token = device_installation_params[:device_token].to_s

        if fake_or_invalid_token?(token)
          Rails.logger.warn(
            "[DeviceInstallations] rejected fake/invalid device_token for account_id=#{current_account.id} " \
            "token_prefix=#{token[0, 16].inspect} length=#{token.length}"
          )
          return render json: {
            errors: [ "device_token does not look like a real FCM token" ]
          }, status: :unprocessable_entity
        end

        installation = DeviceInstallation.find_or_initialize_by(device_token: token)
        was_new = installation.new_record?
        installation.account = current_account
        installation.assign_attributes(
          device_installation_params.merge(active: true, last_seen_at: Time.current)
        )
        installation.save!

        Rails.logger.info(
          "[DeviceInstallations] #{was_new ? 'registered' : 'refreshed'} installation_id=#{installation.id} " \
          "account_id=#{current_account.id} platform=#{installation.platform} token_prefix=#{token[0, 12]}…"
        )

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

      def deactivate
        token = params[:device_token].to_s
        if token.blank?
          return render json: { errors: [ "device_token is required" ] }, status: :unprocessable_entity
        end

        count = DeviceInstallation.where(device_token: token).update_all(active: false, last_seen_at: Time.current)
        Rails.logger.info("[DeviceInstallations] deactivated #{count} installation(s) on logout token_prefix=#{token[0, 12]}…")

        render json: { message: "Device deactivated" }, status: :ok
      end

      def report
        details = params.permit(:stage, :message, :code, :native_error_code, :native_error_message, :platform, :os_version, :device_model, :app_version).to_h

        Rails.logger.warn(
          "[DeviceInstallations][client-fcm-failure] account_id=#{current_account.id} " \
          "#{details.map { |k, v| "#{k}=#{v.inspect}" }.join(' ')}"
        )

        head :no_content
      end

      private

      def fake_or_invalid_token?(token)
        return true if token.blank?
        return true if token.length < MIN_TOKEN_LENGTH
        return true if FAKE_TOKEN_PREFIXES.any? { |p| token.start_with?(p) }

        false
      end

      def device_installation_params
        params.require(:device_installation).permit(:platform, :device_token, :device_id, metadata: {})
      end
    end
  end
end
