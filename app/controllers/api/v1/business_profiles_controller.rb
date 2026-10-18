module Api
  module V1
    class BusinessProfilesController < BaseController
      skip_before_action :authorize_request, only: [ :index, :show, :show_by_uid, :qr_code ]
      before_action :assign_optional_current_account, only: [ :index, :show, :show_by_uid, :qr_code ]
      before_action :set_business_profile, only: [ :show, :update, :destroy, :qr_code, :favorite, :unfavorite, :submit ]
      before_action :ensure_owner!, only: [ :update, :destroy, :submit ]
      before_action :ensure_approved_for_favorite!, only: [ :favorite, :unfavorite ]

      def index
        ranked_page = cached_ranked_page
        business_profiles = load_in_order(ranked_page[:ids])

        if business_profiles.present?
          favorited_ids = current_account ? current_account.favorites.where(business_profile_id: business_profiles.map(&:id)).pluck(:business_profile_id).to_set : Set.new

          render json: {
            business_profiles: BusinessProfileBlueprint.render_as_hash(business_profiles, host: request.base_url, viewer: current_account, include_account: true, include_reviews: false, favorited_ids: favorited_ids),
            meta: ranked_page[:meta]
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

        # Created as a draft: nothing is sent to the admin (or emailed to the
        # expert) until every onboarding step is done and #submit is called.
        business_profile = current_account.build_business_profile(business_profile_params)
        business_profile.approval_status = :draft
        business_profile.rejection_reason = nil
        business_profile.approved_at = nil
        business_profile.save!
        current_account.update!(is_business: false)

        render json: {
          message: "Business profile saved as draft. Complete the remaining steps to submit it for approval.",
          business_profile: BusinessProfileBlueprint.render_as_hash(business_profile, include_account: true)
        }, status: :created
      end

      def update
        # A rejected profile is NOT auto-resubmitted on edit any more; the
        # expert must finish editing and call #submit explicitly.
        #
        # Categories, fees, schedule and availability can be edited freely.
        # Changing business details or GST info on a live (approved/pending)
        # profile sends it back to admin review.
        @business_profile.assign_attributes(business_profile_params)
        needs_review = (@business_profile.approved? || @business_profile.pending?) && review_triggering_change?
        if needs_review
          @business_profile.approval_status = :pending
          @business_profile.approved_at = nil
          @business_profile.rejection_reason = nil
        end
        @business_profile.save!

        if needs_review
          Notifications::Creator.call(
            recipient: current_account,
            actor: current_account,
            notifiable: @business_profile,
            notification_type: "business_profile_resubmitted",
            title: "Business profile sent for re-approval",
            body: "You changed your business details, so your profile is back in admin review.",
            payload: { business_profile_id: @business_profile.id, approval_status: @business_profile.approval_status }
          )
          deliver_review_mails(@business_profile, "updated")
        end

        render json: {
          message: "Business profile updated successfully",
          business_profile: BusinessProfileBlueprint.render_as_hash(@business_profile, include_account: true)
        }, status: :ok
      end

      # POST /business_profiles/:id/submit — final onboarding step.
      def submit
        profile = @business_profile

        if profile.approved? || profile.pending?
          return render json: {
            message: "Business profile is already #{profile.approval_status}",
            business_profile: BusinessProfileBlueprint.render_as_hash(profile, include_account: true)
          }, status: :ok
        end

        missing = profile.missing_onboarding_steps
        if missing.any?
          return render json: { errors: [ "Please complete: #{missing.join(', ')}" ], missing_steps: missing }, status: :unprocessable_entity
        end

        resubmission = profile.rejected?
        profile.update!(approval_status: :pending, rejection_reason: nil, approved_at: nil)

        if resubmission
          Notifications::Creator.call(
            recipient: current_account,
            actor: current_account,
            notifiable: profile,
            notification_type: "business_profile_resubmitted",
            title: "Business profile resubmitted",
            body: "Your updated business profile is back in review.",
            payload: { business_profile_id: profile.id, approval_status: profile.approval_status }
          )
        else
          Notifications::Creator.call(
            recipient: current_account,
            actor: current_account,
            notifiable: profile,
            notification_type: "business_profile_submitted",
            title: "Business profile submitted",
            body: "Your business profile has been sent for admin review.",
            payload: { business_profile_id: profile.id, approval_status: profile.approval_status }
          )
        end

        deliver_review_mails(profile, resubmission ? "resubmitted" : "new")

        render json: {
          message: "Business profile submitted for approval",
          business_profile: BusinessProfileBlueprint.render_as_hash(profile, include_account: true)
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

        share_url = public_expert_url(@business_profile.account.uid, host: request.base_url)
        render json: {
          name: @business_profile.account.full_name,
          share_url: share_url,
          deep_link_url: "previewtax://expert/#{@business_profile.account.uid}",
          qr_code_svg: QrCodeSvg.generate(share_url)
        }, status: :ok
      end

      def show_by_uid
        business_profile = BusinessProfile.includes(account: { profile_pic_attachment: :blob }, categories: {}, schedules: {}, reviews: { account: { profile_pic_attachment: :blob } })
          .joins(:account)
          .find_by!(accounts: { uid: params[:uid] })

        unless business_profile.approved? || (@current_account && business_profile.account_id == @current_account.id)
          raise ActiveRecord::RecordNotFound, "Business profile not found"
        end

        render json: {
          business_profile: BusinessProfileBlueprint.render_as_hash(
            business_profile,
            host: request.base_url,
            viewer: current_account,
            include_account: true
          )
        }, status: :ok
      end

      def favorite
        if @business_profile.account_id == current_account.id
          return render json: { errors: [ "You cannot favorite your own business profile" ] }, status: :unprocessable_entity
        end

        favorite = current_account.favorites.find_or_create_by!(business_profile: @business_profile)
        render json: { message: "Expert added to favorites" }, status: :created
      end

      def unfavorite
        if @business_profile.account_id == current_account.id
          return render json: { errors: [ "You cannot favorite your own business profile" ] }, status: :unprocessable_entity
        end

        favorite = current_account.favorites.find_by!(business_profile: @business_profile)
        favorite.destroy!
        render json: { message: "Expert removed from favorites" }, status: :ok
      end

      def dashboard
        return render json: { error: "Unauthorized access" }, status: :unauthorized unless current_account

        bp = current_account.business_profile || BusinessProfile.find_by(account_id: current_account.id)
        unless bp.present?
          return render json: { error: "Create a business profile to view your expert dashboard." }, status: :forbidden
        end

        # Expensive multi-query aggregate — a minute of staleness on a stats
        # dashboard is imperceptible, and this cuts ~20 queries down to 0 on
        # a cache hit (business owners tend to reload this screen a lot).
        payload = Rails.cache.fetch("business_profiles/dashboard/#{current_account.id}", expires_in: 60.seconds) do
          build_dashboard_payload(current_account, bp)
        end

        render json: payload, status: :ok
      end

      private

      # Emails the expert (confirmation) and every admin (review request).
      # Mail failures must never break the API response.
      def deliver_review_mails(profile, kind)
        AccountAuthMailer.profile_submitted_email(current_account, kind).deliver_later if current_account.email.present?
        AdminNotificationMailer.business_profile_review_request(business_profile_id: profile.id, kind: kind).deliver_later
      rescue StandardError => e
        Rails.logger.error("[BusinessProfile] review mail enqueue failed: #{e.class}: #{e.message}")
      end

      REVIEW_TRIGGER_FIELDS = %w[
        business_name business_address bio about pincode state city
        gst_enabled gst_number
      ].freeze

      # True when the pending (unsaved) assignment touched business details or GST data.
      def review_triggering_change?
        return true if params.dig(:business_profile, :gst_certificate).present?

        # gst_number is normalised before validation, so compare against the normalised value.
        @business_profile.gst_number = @business_profile.gst_number.to_s.strip.upcase.presence
        # nil vs "" and surrounding whitespace are not real edits.
        (@business_profile.changed & REVIEW_TRIGGER_FIELDS).any? do |field|
          before = @business_profile.attribute_in_database(field)
          after = @business_profile[field]
          before.is_a?(String) || after.is_a?(String) ? before.to_s.strip != after.to_s.strip : before != after
        end
      end

      def build_dashboard_payload(current_account, bp)
        acc_id = current_account.id

        # Calls
        received_calls = CallHistory.where(receiver_account_id: acc_id)
        total_calls = received_calls.count
        ended_calls = received_calls.where(status: :ended)
        ended_calls_count = ended_calls.count
        missed_calls = received_calls.where(status: :missed).count
        declined_calls = received_calls.where(status: :declined).count

        missed_calls_pct = total_calls.positive? ? ((missed_calls.to_f / total_calls) * 100).round(1) : 0.0
        declined_calls_pct = total_calls.positive? ? ((declined_calls.to_f / total_calls) * 100).round(1) : 0.0

        audio_calls_scope = received_calls.where(call_type: "voice")
        video_calls_scope = received_calls.where(call_type: "video")

        audio_calls_count = audio_calls_scope.count
        video_calls_count = video_calls_scope.count

        audio_duration_seconds = audio_calls_scope.where(status: :ended).sum(:duration_seconds)
        video_duration_seconds = video_calls_scope.where(status: :ended).sum(:duration_seconds)
        total_duration_seconds = ended_calls.sum(:duration_seconds)

        audio_mins = (audio_duration_seconds / 60.0).round(1)
        video_mins = (video_duration_seconds / 60.0).round(1)
        total_mins = (total_duration_seconds / 60.0).round(1)

        avg_duration_sec = ended_calls_count.positive? ? (total_duration_seconds / ended_calls_count.to_f).round : 0

        # Chat Sessions
        chat_sessions_scope = ChatSession.where(business_profile_id: bp.id)
        ended_chats = chat_sessions_scope.where(status: :ended)
        chat_sessions_count = ended_chats.count
        chat_billed_minutes = ended_chats.sum(:billed_minutes)
        chat_earnings = ended_chats.sum(:total_amount)

        # Revenue & Financials
        audio_earnings = audio_calls_scope.where(status: :ended).sum(:amount_charged)
        video_earnings = video_calls_scope.where(status: :ended).sum(:amount_charged)
        total_call_earnings = audio_earnings + video_earnings

        wallet_earnings = current_account.wallet_transactions.where(transaction_type: :credit, entry_type: "earnings").sum(:amount)
        calculated_total_earnings = [ wallet_earnings, (total_call_earnings + chat_earnings) ].max

        completed_withdrawals = current_account.withdrawal_requests.where(status: [ :approved, :completed ]).sum(:amount)
        pending_withdrawals = current_account.withdrawal_requests.where(status: :pending).sum(:amount)

        # Repeat clients calculation
        callers_counts = ended_calls.group(:caller_account_id).count
        unique_callers = callers_counts.keys.size
        repeat_callers_count = callers_counts.values.count { |count| count > 1 }
        repeat_clients_pct = unique_callers.positive? ? ((repeat_callers_count.to_f / unique_callers) * 100).round(1) : 0.0

        share_url = "https://previewtax.com/expert/#{current_account.uid}"

        {
          profile: {
            business_name: bp.business_name,
            full_name: current_account.full_name,
            username: current_account.username,
            uid: current_account.uid,
            profile_pic_url: current_account.profile_pic_url,
            is_verified: current_account.is_verified?,
            chat_price: bp.chat_price.to_i,
            call_price: bp.call_price.to_i,
            v_call_price: bp.v_call_price.to_i,
            share_url: share_url
          },
          revenue: {
            earnings_balance: current_account.earnings_balance.to_i,
            wallet_balance: current_account.wallet_balance.to_i,
            total_earnings: calculated_total_earnings.to_i,
            withdrawals_total: completed_withdrawals.to_i,
            withdrawals_pending: pending_withdrawals.to_i,
            video_call_earnings: video_earnings.to_i,
            audio_call_earnings: audio_earnings.to_i,
            chat_earnings: chat_earnings.to_i
          },
          calls: {
            total_calls: total_calls,
            ended_calls_count: ended_calls_count,
            audio_calls: audio_calls_count,
            video_calls: video_calls_count,
            video_mins: video_mins,
            audio_mins: audio_mins,
            total_call_mins: total_mins,
            avg_duration_seconds: avg_duration_sec,
            chat_sessions_count: chat_sessions_count,
            chat_billed_minutes: chat_billed_minutes,
            total_consultations: ended_calls_count + chat_sessions_count
          },
          quality: {
            avg_rating: bp.avg_rating.to_f.round(1),
            reviews_count: bp.reviews_count.to_i,
            missed_calls_count: missed_calls,
            missed_calls_pct: missed_calls_pct,
            declined_calls_count: declined_calls,
            declined_calls_pct: declined_calls_pct,
            repeat_clients_count: repeat_callers_count,
            repeat_clients_pct: repeat_clients_pct,
            unique_clients_count: unique_callers
          }
        }
      end

      def set_business_profile
        @business_profile = BusinessProfile.includes(account: { profile_pic_attachment: :blob }, categories: {}, schedules: {}, reviews: { account: { profile_pic_attachment: :blob } }).find(params[:id])
      end

      def ensure_owner!
        return if @business_profile.account_id == current_account.id

        render json: { errors: [ "You are not allowed to modify this business profile" ] }, status: :forbidden
      end

      def ensure_approved_for_favorite!
        return if @business_profile.approved?

        render json: { errors: [ "Only approved business profiles can be favorited" ] }, status: :unprocessable_entity
      end

      RANKED_PAGE_TTL = 30.seconds

      # The expensive part of the expert list is the live ranking query (verified /
      # consultations / rating subqueries + count). Cache just the ordered ids and
      # page meta for a short time; records, viewer-specific favorite flags and live
      # availability are still rendered fresh on every request.
      def cached_ranked_page
        own_account_id = own_expert_account_id
        key = [
          "experts/index/v1",
          params[:q].to_s.downcase.strip,
          Array(params[:category_ids]).join(","),
          params[:sort].to_s,
          params[:page].to_i,
          per_page,
          own_account_id,
          BusinessProfile.maximum(:updated_at)&.to_f
        ].join("/")

        Rails.cache.fetch(key, expires_in: RANKED_PAGE_TTL) do
          scope = BusinessProfile.where(approval_status: :approved)
          scope = scope.where.not(account_id: own_account_id) if own_account_id
          page = apply_search(scope).ranked(params[:sort]).page(params[:page]).per(per_page)
          { meta: pagination_meta(page), ids: page.pluck(:id) }
        end
      end

      # Viewers who own an expert profile never see themselves in the list.
      def own_expert_account_id
        return nil if @current_account.blank?

        BusinessProfile.exists?(account_id: @current_account.id) ? @current_account.id : nil
      end

      def load_in_order(ids)
        return [] if ids.blank?

        records = BusinessProfile.includes(account: { profile_pic_attachment: :blob }, categories: {}, schedules: {})
                                 .where(id: ids).index_by(&:id)
        ids.filter_map { |id| records[id] }
      end

      def apply_search(scope)
        if params[:q].present?
          query = "%#{params[:q].to_s.downcase.strip}%"
          scope = scope.where(
            "business_profiles.business_name ILIKE :query
            OR business_profiles.city ILIKE :query
            OR business_profiles.state ILIKE :query
            OR business_profiles.account_id IN (SELECT id FROM accounts WHERE full_name ILIKE :query AND deleted_at IS NULL)
            OR business_profiles.id IN (
              SELECT bpc.business_profile_id FROM business_profile_categories bpc
              JOIN categories c ON c.id = bpc.category_id
              WHERE c.name ILIKE :query
            )",
            query: query
          )
        end

        if params[:category_ids].present?
          category_ids = Array(params[:category_ids]).flat_map { |value| value.to_s.split(",") }.map(&:to_i).uniq
          scope = scope.where(id: BusinessProfileCategory.where(category_id: category_ids).select(:business_profile_id)) if category_ids.any?
        end

        scope
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
