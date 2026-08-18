module Api
  module V1
    class ReviewsController < BaseController
      skip_before_action :authorize_request, only: [ :index ]
      before_action :assign_optional_current_account, only: [ :index ]
      before_action :set_business_profile, only: [ :index, :create ]
      before_action :set_review, only: [ :update, :destroy ]
      before_action :ensure_owner!, only: [ :update, :destroy ]

      def index
        reviews = @business_profile.reviews.includes(account: { profile_pic_attachment: :blob }).order(created_at: :desc).page(params[:page]).per(per_page)
        render json: {
          reviews: ReviewBlueprint.render_as_hash(reviews),
          meta: pagination_meta(reviews)
        }, status: :ok
      end

      def create
        review = Review.find_or_initialize_by(account_id: current_account.id, business_profile_id: @business_profile.id)
        is_new = review.new_record?
        review.assign_attributes(review_params)
        review.save!

        notify_review_change(review, created: is_new)
        ActivityLogger.log(account: current_account, event: is_new ? "REVIEW_CREATE" : "REVIEW_UPDATE", title: "#{is_new ? 'Submitted' : 'Updated'} #{review.rating}-star review for #{@business_profile.business_name}", ip_address: request.remote_ip)

        render json: {
          message: "Review submitted successfully",
          review: ReviewBlueprint.render_as_hash(review)
        }, status: :created
      end

      def update
        @review.update!(review_params)
        notify_review_change(@review, created: false)
        ActivityLogger.log(account: current_account, event: "REVIEW_UPDATE", title: "Updated #{@review.rating}-star review for #{@review.business_profile.business_name}", ip_address: request.remote_ip)

        render json: {
          message: "Review updated successfully",
          review: ReviewBlueprint.render_as_hash(@review)
        }, status: :ok
      end

      def destroy
        biz_name = @review.business_profile.business_name
        @review.destroy!
        ActivityLogger.log(account: current_account, event: "REVIEW_DELETE", title: "Deleted review for #{biz_name}", ip_address: request.remote_ip)
        render json: { message: "Review deleted successfully" }, status: :ok
      end

      private

      def review_params
        params.require(:review).permit(:rating, :comment)
      end

      def set_business_profile
        @business_profile = BusinessProfile.find(params[:business_profile_id])
        return if @business_profile.approved? || (@current_account && @business_profile.account_id == @current_account.id)

        raise ActiveRecord::RecordNotFound, "Business profile not found"
      end

      def set_review
        @review = Review.find(params[:id])
      end

      def ensure_owner!
        return if @review.account_id == current_account.id

        render json: {
          errors: ["You are not allowed to modify this review"]
        }, status: :forbidden
      end

      def notify_review_change(review, created:)
        return if @business_profile.account_id == current_account.id

        Notifications::Creator.call(
          recipient: @business_profile.account,
          actor: current_account,
          notifiable: review,
          notification_type: created ? "review_created" : "review_updated",
          title: created ? "New review received" : "Review updated",
          body: "#{current_account.full_name} #{created ? 'left' : 'updated'} a #{review.rating}-star review on your profile.",
          payload: { business_profile_id: @business_profile.id, review_id: review.id, rating: review.rating }
        )
      end
    end
  end
end
