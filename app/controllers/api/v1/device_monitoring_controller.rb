module Api
  module V1
    class DeviceMonitoringController < BaseController
      skip_before_action :authorize_request, only: [ :sync ]
      before_action :assign_optional_current_account, only: [ :sync ]
      before_action :authorize_request, only: [ :activity, :user_logs ]

      def sync
        device_uuid = params.require(:device_uuid)
        server_ip = request.remote_ip

        device = Device.find_or_initialize_by(device_uuid: device_uuid)
        device.account = current_account if current_account.present?
        device.manufacturer = params[:manufacturer] if params[:manufacturer].present?
        device.model = params[:model] if params[:model].present?
        device.android_version = params[:android_version] if params[:android_version].present?
        device.android_api_level = params[:android_api_level] if params[:android_api_level].present?
        device.app_version = params[:app_version] || "1.0.0"
        device.app_build = params[:app_build] || 1
        device.network_type = params[:network_type] if params[:network_type].present?
        device.push_token = params[:push_token] if params[:push_token].present?
        device.last_ip = server_ip
        device.first_seen_at ||= Time.current
        device.last_seen_at = Time.current
        device.save!

        if current_account.present?
          session = DeviceSession.find_or_initialize_by(account: current_account, device: device, logout_at: nil)
          session.ip_address = server_ip
          session.network_type = params[:network_type] || device.network_type
          session.app_version = device.app_version
          session.android_version = device.android_version
          session.login_at ||= Time.current
          session.last_seen_at = Time.current
          session.save!

          if params[:push_token].present?
            inst = DeviceInstallation.find_or_initialize_by(device_token: params[:push_token])
            inst.account = current_account
            inst.platform = params[:platform] || "android"
            inst.active = true
            inst.last_seen_at = Time.current
            inst.save!
          end
        end

        render json: {
          status: "ok",
          device_id: device.id,
          server_ip: server_ip,
          app_version: device.app_version,
          app_build: device.app_build
        }, status: :ok
      rescue ActionController::ParameterMissing => error
        render json: { errors: [ error.message ] }, status: :unprocessable_entity
      rescue StandardError => error
        Rails.logger.error("[device_monitoring#sync] #{error.class}: #{error.message}")
        render json: { errors: [ "Unable to sync device" ] }, status: :unprocessable_entity
      end

      def activity
        event = params.require(:event)
        title = params[:title] || event.humanize
        device = Device.find_by(device_uuid: params[:device_uuid]) if params[:device_uuid].present?

        log = ActivityLog.create!(
          account: current_account,
          device: device,
          event: event,
          title: title,
          metadata: params[:metadata] || {},
          ip_address: request.remote_ip
        )

        render json: { status: "ok", log_id: log.id }, status: :created
      rescue => error
        render_service_error(error)
      end

      def user_logs
        logs = current_account.activity_logs.user_visible.recent.page(params[:page] || 1).per(params[:per_page] || 20)

        formatted_logs = logs.map do |log|
          {
            id: log.id,
            event: log.event,
            title: log.title || log.event.humanize,
            metadata: log.metadata,
            created_at: log.created_at.iso8601,
            time_ago: time_ago_in_words(log.created_at)
          }
        end

        render json: {
          activity_logs: formatted_logs,
          meta: pagination_meta(logs)
        }, status: :ok
      end

      private

      def time_ago_in_words(time)
        return "" unless time.present?
        seconds = (Time.current - time).to_i
        return "Just now" if seconds < 60
        return "#{seconds / 60}m ago" if seconds < 3600
        return "#{seconds / 3600}h ago" if seconds < 86400
        "#{seconds / 86400}d ago"
      end
    end
  end
end
