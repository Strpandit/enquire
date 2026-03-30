module Api
  module V1
    class AccountsController < BaseController
      def index
        accounts = Account.order(created_at: :desc).page(params[:page]).per(per_page)
        render json: {
          accounts: AccountBlueprint.render_as_hash(accounts),
          meta: pagination_meta(accounts)
        }, status: :ok
      end

      def show
        render json: {
          account: AccountBlueprint.render_as_hash(current_account, include_business: true)
        }, status: :ok
      end

      def update
        current_account.update!(account_params)

        render json: {
          message: "Profile updated successfully",
          account: AccountBlueprint.render_as_hash(current_account, include_business: true)
        }, status: :ok
      end

      def toggle_business
        render json: {
          message: "Business mode is controlled by profile approval. Create a business profile and wait for admin review."
        }, status: :ok
      end

      def submit_verification
        current_account.assign_attributes(verification_params)
        current_account.verification_status = :pending
        current_account.verification_rejection_reason = nil
        current_account.save!

        Notifications::Creator.call(
          recipient: current_account,
          actor: current_account,
          notifiable: current_account,
          notification_type: "verification_submitted",
          title: "Verification submitted",
          body: "Your verification documents are under review.",
          payload: { verification_status: current_account.verification_status }
        )

        render json: {
          message: "Verification submitted successfully",
          account: AccountBlueprint.render_as_hash(current_account)
        }, status: :ok
      end

      def change_password
        if current_account.authenticate(params[:current_password])
          if current_account.update(password: params[:new_password], password_confirmation: params[:confirm_password])
            render json: { message: "Password updated successfully", status: 200 }, status: :ok
          else
            render json: { errors: current_account.errors.full_messages }, status: :unprocessable_entity
          end
        else
          render json: { errors: "Incorrect current password" }, status: :unprocessable_entity
        end
      end

      def destroy
        user = Account.with_deleted.find_by(id: params[:id])

        return render json: { message: "Account not found" }, status: :not_found unless user

        unless params[:password].present?
          return render json: { message: "Password is required" }, status: :unprocessable_entity
        end

        unless user.authenticate(params[:password])
          return render json: { message: "Incorrect password" }, status: :unauthorized
        end

        if user.destroy
          render json: { message: "Account deleted successfully" }, status: :ok
        else
          render json: { message: "Unable to delete account" }, status: :unprocessable_entity
        end
      end

      private

      def account_params
        permitted = params.require(:account).permit(
          :full_name, :phone, :state, :district, :city, :pincode, :password,
          :password_confirmation, :username, :profile_pic, languages: []
        )

        permitted.delete(:username) if permitted[:username].to_s.strip.blank?
        permitted
      end

      def verification_params
        params.permit(:phone, :pan_card, :aadhaar_card, :passport_photo)
      end
    end
  end
end
