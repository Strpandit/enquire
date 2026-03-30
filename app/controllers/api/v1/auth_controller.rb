module Api
  module V1
    class AuthController < ActionController::API
      OTP_RESEND_COOLDOWN = 1.minute

      rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
      rescue_from ActionController::ParameterMissing, with: :render_parameter_missing

      def signup
        account = Account.new(sign_up_params)
        account.save!

        render json: {
          account: JSON.parse(AccountBlueprint.render(account)),
          token: JsonWebToken.encode(account_id: account.id),
          message: "Account created successfully"
        }, status: :created
      end

      def login
        account = Account.find_by!(email: login_params[:email].to_s.downcase)

        unless account.authenticate(login_params[:password])
          return render json: { errors: [ "Invalid email or password" ] }, status: :unauthorized
        end

        render json: {
          account: JSON.parse(AccountBlueprint.render(account)),
          token: JsonWebToken.encode(account_id: account.id),
          message: "Login successful"
        }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { errors: [ "Invalid email or password" ] }, status: :unauthorized
      end

      def forgot_password
        email = forgot_password_params[:email].to_s.downcase
        account = Account.find_by(email: email)

        if account&.otp_sent_at.present? && account.otp_sent_at > OTP_RESEND_COOLDOWN.ago
          return render json: {
            errors: ["OTP already sent recently. Please wait a minute before requesting another."]
          }, status: :too_many_requests
        end

        if account.present?
          account.generate_password_reset_otp!
          AccountAuthMailer.forgot_password_otp(account).deliver_later
        end

        render json: {
          message: "If an account with this email exists, an OTP has been sent."
        }, status: :ok
      end

      def otp_confirmation
        account = Account.find_by(email: otp_confirmation_params[:email].to_s.downcase)

        unless account&.password_reset_otp_valid?(otp_confirmation_params[:otp])
          return render json: { errors: [ "Invalid or expired OTP" ] }, status: :unprocessable_entity
        end

        reset_token = account.generate_reset_password_token!

        render json: {
          message: "OTP verified successfully",
          reset_password_token: reset_token,
          reset_password_expires_at: account.reset_password_sent_at + Account::PASSWORD_RESET_TOKEN_WINDOW
        }, status: :ok
      end

      def verify_reset_token
        account = Account.find_by(email: verify_reset_token_params[:email].to_s.downcase)

        unless account&.valid_reset_password_token?(verify_reset_token_params[:reset_password_token])
          return render json: { errors: [ "Invalid or expired reset token" ] }, status: :unprocessable_entity
        end

        render json: { message: "Reset token is valid" }, status: :ok
      end

      def reset_password
        account = Account.find_by(email: reset_password_params[:email].to_s.downcase)

        unless account&.valid_reset_password_token?(reset_password_params[:reset_password_token])
          return render json: { errors: [ "Invalid or expired reset token" ] }, status: :unprocessable_entity
        end

        account.update!(
          password: reset_password_params[:password],
          password_confirmation: reset_password_params[:password_confirmation]
        )
        account.clear_password_reset_credentials!
        AccountAuthMailer.password_reset_confirmation(account).deliver_later

        render json: { message: "Password reset successfully" }, status: :ok
      end

      private

      def sign_up_params
        params.require(:account).permit(:full_name, :email, :password, :password_confirmation)
      end

      def login_params
        params.require(:account).permit(:email, :password)
      end

      def forgot_password_params
        params.require(:account).permit(:email)
      end

      def otp_confirmation_params
        params.require(:account).permit(:email, :otp)
      end

      def verify_reset_token_params
        params.require(:account).permit(:email, :reset_password_token)
      end

      def reset_password_params
        params.require(:account).permit(:email, :reset_password_token, :password, :password_confirmation)
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

