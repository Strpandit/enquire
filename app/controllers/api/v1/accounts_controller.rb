module Api
  module V1
    class AccountsController < BaseController
      def show
        render json: {
          account: AccountBlueprint.render_as_hash(current_account, include_business: true, include_private: true, viewer: current_account)
        }, status: :ok
      end

      def update
        current_account.update!(account_params)
        ActivityLogger.log(account: current_account, event: "PROFILE_UPDATE", title: "Updated personal profile details", ip_address: request.remote_ip)

        render json: {
          message: "Profile updated successfully",
          account: AccountBlueprint.render_as_hash(current_account, include_business: true, include_private: true, viewer: current_account)
        }, status: :ok
      end

      def toggle_business
        render json: {
          message: "Business mode is controlled by profile approval. Create a business profile and wait for admin review."
        }, status: :ok
      end

      def submit_verification
        payment_method = params[:payment_method].to_s.presence || "wallet"
        order_id = params[:order_id].to_s.presence
        fee_required = !current_account.rejected? && !current_account.is_verified?

        if fee_required
          if payment_method == "cashfree"
            raise ActionController::ParameterMissing, "order_id is required for online payment" if order_id.blank?

            if Cashfree::PaymentService.extract_account_id(order_id) != current_account.id
              return render json: { errors: [ "Payment order does not belong to your account" ] }, status: :forbidden
            end

            result = Cashfree::PaymentService.get_order_status(order_id: order_id)
            unless result[:order_status] == "PAID"
              return render json: { errors: [ "Verification payment was not completed (Status: #{result[:order_status]})" ] }, status: :unprocessable_entity
            end

            paid_amount = result[:amount].to_i
            if paid_amount < Account::VERIFICATION_PRICE
              return render json: { errors: [ "Paid amount (₹#{paid_amount}) is less than required verification fee (₹#{Account::VERIFICATION_PRICE})" ] }, status: :unprocessable_entity
            end

            ActivityLogger.log(
              account: current_account,
              event: "VERIFICATION_PAID_ONLINE",
              title: "Paid ₹#{paid_amount} for Verification Badge via Cashfree (Order: #{order_id})",
              metadata: { order_id: order_id, amount: paid_amount },
              ip_address: request.remote_ip
            )
          elsif payment_method == "wallet"
            current_account.with_lock do
              if current_account.wallet_balance < Account::VERIFICATION_PRICE
                return render json: {
                  errors: [ "Insufficient wallet balance (₹#{current_account.wallet_balance} available, ₹#{Account::VERIFICATION_PRICE} required). Please pay via UPI/Cashfree or top up your wallet." ]
                }, status: :unprocessable_entity
              end

              Wallets::LedgerService.debit!(
                account: current_account,
                amount: Account::VERIFICATION_PRICE,
                description: "Verification Badge Fee (180 Days)",
                metadata: { type: "verification_fee", cycle_days: Account::VERIFICATION_CYCLE_DAYS },
                idempotency_key: "verification_fee_#{current_account.id}_#{Time.current.strftime('%Y%m%d%H%M')}"
              )
            end
          else
            return render json: { errors: [ "Invalid payment method" ] }, status: :unprocessable_entity
          end
        end

        current_account.assign_attributes(verification_params)
        current_account.verification_status = :pending
        current_account.verification_rejection_reason = nil
        current_account.save!

        ActivityLogger.log(account: current_account, event: "VERIFICATION_SUBMIT", title: "Submitted KYC verification documents for approval", ip_address: request.remote_ip)

        Notifications::Creator.call(
          recipient: current_account,
          actor: current_account,
          notifiable: current_account,
          notification_type: "verification_submitted",
          title: "Verification submitted",
          body: "Your verification documents and payment have been received and are under review.",
          payload: { verification_status: current_account.verification_status }
        )

        render json: {
          message: "Verification submitted successfully with payment!",
          account: AccountBlueprint.render_as_hash(current_account, include_private: true, viewer: current_account)
        }, status: :ok
      rescue => error
        render_service_error(error)
      end

      def change_password
        if current_account.authenticate(params[:current_password])
          if current_account.update(password: params[:new_password], password_confirmation: params[:confirm_password])
            ActivityLogger.log(account: current_account, event: "PASSWORD_CHANGE", title: "Updated account security password", ip_address: request.remote_ip)
            render json: { message: "Password updated successfully", status: 200, token: JsonWebToken.encode_for(current_account) }, status: :ok
          else
            render json: { errors: current_account.errors.full_messages }, status: :unprocessable_entity
          end
        else
          render json: { errors: "Incorrect current password" }, status: :unprocessable_entity
        end
      end

      def destroy
        user = current_account

        unless params[:password].present?
          return render json: { message: "Password is required" }, status: :unprocessable_entity
        end

        unless user.authenticate(params[:password])
          return render json: { message: "Incorrect password" }, status: :unauthorized
        end

        if user.destroy
          ActivityLogger.log(account: user, event: "ACCOUNT_DELETED", title: "Deleted account permanently", ip_address: request.remote_ip)
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
        params.permit(:pan_card, :aadhaar_card, :aadhaar_card_back, :gst_certificate, education_documents: [])
      end
    end
  end
end
