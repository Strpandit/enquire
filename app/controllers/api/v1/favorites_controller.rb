module Api
  module V1
    class FavoritesController < BaseController
      def index
        favorites = current_account.favorite_business_profiles.includes(:account, :categories, :schedules)
                         .where(approval_status: :approved)
                         .order(created_at: :desc)
                         .page(params[:page]).per(per_page)

        render json: {
          business_profiles: BusinessProfileBlueprint.render_as_hash(favorites, include_account: true),
          meta: pagination_meta(favorites)
        }, status: :ok
      end
    end
  end
end
