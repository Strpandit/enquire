module Api
  module V1
    class CategoriesController < BaseController
      skip_before_action :authorize_request, only: [ :index, :show ]
      before_action :assign_optional_current_account, only: [ :index, :show ]

      def index
        categories = Category.order(:name)
        categories = categories.where("LOWER(name) LIKE ?", "%#{params[:q].to_s.downcase.strip}%") if params[:q].present?
        categories = categories.page(params[:page]).per(per_page)

        if categories.present?
          cache_key = [ "categories/index", params[:q].to_s.downcase.strip, params[:page], per_page, Category.maximum(:updated_at)&.to_i ].join("/")
          payload = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
            {
              categories: CategoryBlueprint.render_as_hash(categories),
              meta: pagination_meta(categories)
            }
          end
          render json: payload, status: :ok
        else
          render json: { message: "No categories found" }, status: :not_found
        end
      end

      def show
        category = Category.find_by(id: params[:id])
        if category
          cache_key = "categories/show/#{category.id}-#{category.updated_at.to_i}"
          payload = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
            { category: CategoryBlueprint.render_as_hash(category) }
          end
          render json: payload, status: :ok
        else
          render json: { message: "Category not found" }, status: :not_found
        end
      end
    end
  end
end
