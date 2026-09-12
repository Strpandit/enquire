module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::MimeResponds

      # ActionController::API doesn't set this the way a full Rails app does,
      # but ActiveStorage::Blob#url (called directly, e.g. for avatar
      # thumbnails) needs it to build an absolute URL on non-Cloudinary
      # services (local Disk in dev/test) — without it, any direct .url()
      # call raises ArgumentError.
      before_action :set_active_storage_url_options
      before_action :authorize_request

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
      rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
      rescue_from JWT::DecodeError, JWT::VerificationError, JWT::ExpiredSignature, with: :render_unauthorized

      attr_reader :current_account

      private

      def set_active_storage_url_options
        ActiveStorage::Current.url_options = { host: request.host, port: request.port, protocol: request.protocol }
      end

      def authorize_request
        token = bearer_token
        raise JWT::DecodeError if token.blank?

        payload = JsonWebToken.decode(token)
        @current_account = Account.find(payload.fetch("account_id"))

        if payload["pwd"].present? && payload["pwd"] != @current_account.password_token_fingerprint
          render_unauthorized
        end
      rescue ActiveRecord::RecordNotFound, KeyError, NoMethodError
        render_unauthorized
      end

      def assign_optional_current_account
        token = bearer_token
        return if token.blank?

        payload = JsonWebToken.decode(token)
        @current_account = Account.find(payload.fetch("account_id"))
      rescue JWT::DecodeError, JWT::VerificationError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound, KeyError, NoMethodError
        @current_account = nil
      end

      def pagination_meta(collection)
        {
          current_page: collection.current_page,
          next_page: collection.next_page,
          prev_page: collection.prev_page,
          total_pages: collection.total_pages,
          total_count: collection.total_count,
          per_page: collection.limit_value
        }
      end

      def per_page
        requested = params[:per_page].to_i
        return 10 if requested <= 0

        [ requested, 50 ].min
      end

      def bearer_token
        request.headers["Authorization"]&.split&.last
      end

      # Only surface messages from errors we deliberately raise for the user.
      # Everything else gets a generic message + a full server-side log entry,
      # so internal / DB details never leak to the client.
      SAFE_ERROR_CLASSES = [
        "Calls::HistoryService::Error",
        "Cashfree::PaymentService::Error",
        "Wallets::LedgerService::Error",
        "Chat::SessionService::Error",
        "Chat::MessageService::Error",
        "ActiveRecord::RecordInvalid",
        "ActionController::ParameterMissing"
      ].freeze

      def render_service_error(error, status: :unprocessable_entity)
        if SAFE_ERROR_CLASSES.include?(error.class.name)
          render json: { errors: [ error.message ] }, status: status
        else
          Rails.logger.error("[#{controller_name}##{action_name}] #{error.class}: #{error.message}\n#{Array(error.backtrace).first(5).join("\n")}")
          render json: { errors: [ "Something went wrong. Please try again." ] }, status: :internal_server_error
        end
      end

      def render_unauthorized
        render json: { errors: [ "Unauthorized access" ] }, status: :unauthorized
      end

      def render_not_found(error)
        render json: { errors: [ error.message ] }, status: :not_found
      end

      def render_record_invalid(error)
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      end

      def render_parameter_missing(error)
        render json: { errors: [ error.message ] }, status: :unprocessable_entity
      end
    end
  end
end
