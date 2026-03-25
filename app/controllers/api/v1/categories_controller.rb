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
          render json: {
            categories: CategoryBlueprint.render_as_hash(categories),
            meta: pagination_meta(categories)
          }, status: :ok
        else
          render json: { message: "No categories found" }, status: :not_found
        end
      end

      def show
        category = Category.find_by(id: params[:id])
        if category
          render json: { category: CategoryBlueprint.render_as_hash(category) }, status: :ok
        else
          render json: { message: "Category not found" }, status: :not_found
        end
      end
    end
  end
end
