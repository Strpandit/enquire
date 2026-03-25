module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::MimeResponds

      before_action :authorize_request

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
      rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
      rescue_from JWT::DecodeError, JWT::VerificationError, JWT::ExpiredSignature, with: :render_unauthorized

      attr_reader :current_account

      private

      def authorize_request
        token = bearer_token
        raise JWT::DecodeError if token.blank?

        payload = JsonWebToken.decode(token)
        @current_account = Account.find(payload.fetch("account_id"))
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

        [requested, 50].min
      end

      def bearer_token
        request.headers["Authorization"]&.split&.last
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
