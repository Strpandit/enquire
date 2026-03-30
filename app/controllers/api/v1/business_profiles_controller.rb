module Api
  module V1
    class BusinessProfilesController < BaseController
      skip_before_action :authorize_request, only: [ :index, :show, :qr_code ]
      before_action :assign_optional_current_account, only: [ :index, :show, :qr_code ]
      before_action :set_business_profile, only: [ :show, :update, :destroy, :qr_code, :favorite, :unfavorite ]
      before_action :authorize_request, only: [ :create, :update, :destroy, :favorite, :unfavorite ]
      before_action :ensure_owner!, only: [ :update, :destroy ]
      before_action :ensure_approved_for_favorite!, only: [ :favorite, :unfavorite ]

      def index
        business_profiles = BusinessProfile.includes(:account, :categories, :schedules)
        business_profiles = business_profiles.where(approval_status: :approved)
        business_profiles = apply_search(business_profiles)
        business_profiles = business_profiles.order(avg_rating: :desc, created_at: :desc).page(params[:page]).per(per_page)

        if business_profiles.present?
          render json: {
            business_profiles: BusinessProfileBlueprint.render_as_hash(business_profiles, host: request.base_url, viewer: current_account, include_account: true),
            meta: pagination_meta(business_profiles)
          }, status: :ok
        else
          render json: { message: "No Experts found" }, status: :not_found
        end
      end

      def show
        unless @business_profile.approved? || (@current_account && @business_profile.account_id == @current_account.id)
          raise ActiveRecord::RecordNotFound, "Business profile not found"
        end

        render json: {
          business_profile: BusinessProfileBlueprint.render_as_hash(@business_profile, host: request.base_url, viewer: current_account, include_account: true)
        }, status: :ok
      end

      def create
        if current_account.business_profile.present?
          return render json: { errors: [ "Business profile already exists" ] }, status: :unprocessable_entity
        end

        business_profile = current_account.build_business_profile(business_profile_params)
        business_profile.approval_status = :pending
        business_profile.rejection_reason = nil
        business_profile.approved_at = nil
        business_profile.save!
        current_account.update!(is_business: false)

        AccountAuthMailer.welcome_email(current_account).deliver_later if current_account.email.present?
        Notifications::Creator.call(
          recipient: current_account,
          actor: current_account,
          notifiable: business_profile,
          notification_type: "business_profile_submitted",
          title: "Business profile submitted",
          body: "Your business profile has been sent for admin review.",
          payload: { business_profile_id: business_profile.id, approval_status: business_profile.approval_status }
        )

        render json: {
          message: "Business profile submitted for approval",
          business_profile: BusinessProfileBlueprint.render_as_hash(business_profile, include_account: true)
        }, status: :created
      end

      def update
        was_rejected = @business_profile.rejected?
        @business_profile.assign_attributes(business_profile_params)
        if was_rejected
          @business_profile.approval_status = :pending
          @business_profile.rejection_reason = nil
          @business_profile.approved_at = nil
        end
        @business_profile.save!

        if was_rejected
          Notifications::Creator.call(
            recipient: current_account,
            actor: current_account,
            notifiable: @business_profile,
            notification_type: "business_profile_resubmitted",
            title: "Business profile resubmitted",
            body: "Your updated business profile is back in review.",
            payload: { business_profile_id: @business_profile.id, approval_status: @business_profile.approval_status }
          )
        end

        render json: {
          message: "Business profile updated successfully",
          business_profile: BusinessProfileBlueprint.render_as_hash(@business_profile, include_account: true)
        }, status: :ok
      end

      def destroy
        ActiveRecord::Base.transaction do
          @business_profile.destroy!
          current_account.update!(is_business: false)
        end

        render json: { message: "Business profile deleted successfully" }, status: :ok
      end

      def qr_code
        unless @business_profile.approved? || (@current_account && @business_profile.account_id == @current_account.id)
          raise ActiveRecord::RecordNotFound, "Business profile not found"
        end

        share_url = public_profile_url(@business_profile.share_token, host: request.base_url)
        render json: {
          name: @business_profile.account.full_name,
          share_url: share_url,
          deep_link_url: "enquire://business_profiles/#{@business_profile.account.uid}?share_token=#{@business_profile.share_token}",
          qr_code_svg: QrCodeSvg.generate(share_url)
        }, status: :ok
      end

      def favorite
        favorite = current_account.favorites.find_or_create_by!(business_profile: @business_profile)
        render json: { message: "Expert added to favorites" }, status: :created
      end

      def unfavorite
        favorite = current_account.favorites.find_by!(business_profile: @business_profile)
        favorite.destroy!
        render json: { message: "Expert removed from favorites" }, status: :ok
      end

      private

      def set_business_profile
        @business_profile = BusinessProfile.includes(:account, :categories, :schedules, reviews: :account).find(params[:id])
      end

      def ensure_owner!
        return if @business_profile.account_id == current_account.id

        render json: { errors: [ "You are not allowed to modify this business profile" ] }, status: :forbidden
      end

      def ensure_approved_for_favorite!
        return if @business_profile.approved?

        render json: { errors: [ "Only approved business profiles can be favorited" ] }, status: :unprocessable_entity
      end

      def apply_search(scope)
        if params[:q].present?
          query = "%#{params[:q].to_s.downcase.strip}%"
          scope = scope.where(
            "LOWER(business_name) LIKE :query OR LOWER(city) LIKE :query OR LOWER(state) LIKE :query",
            query: query
          )
        end

        if params[:category_ids].present?
          category_ids = Array(params[:category_ids]).flat_map { |value| value.to_s.split(',') }.map(&:to_i).uniq
          scope = scope.joins(:business_profile_categories).where(business_profile_categories: { category_id: category_ids }) if category_ids.any?
        end

        scope.distinct
      end

      def business_profile_params
        params.require(:business_profile).permit(
          :chat_price, :call_price, :v_call_price, :is_available, :gst_enabled,
          :gst_number, :business_name, :business_address, :bio, :about, :pincode, :state, :city, :gst_certificate, category_ids: []
        )
      end
    end
  end
end
