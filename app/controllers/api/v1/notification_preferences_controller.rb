module Api
  module V1
    class NotificationPreferencesController < BaseController
      def show
        render json: { preferences: preferences_payload }, status: :ok
      end

      def update
        incoming = params.fetch(:preferences, {}).permit(*Notification::CATEGORIES)
        merged = current_account.notification_preferences.to_h.dup

        incoming.each do |category, value|
          merged[category] = ActiveModel::Type::Boolean.new.cast(value) != false
        end

        current_account.update_column(:notification_preferences, merged)

        render json: { preferences: preferences_payload, unread_count: current_account.unread_notifications_count }, status: :ok
      end

      private

      def preferences_payload
        stored = current_account.notification_preferences.to_h
        Notification::CATEGORIES.index_with { |category| stored[category] != false }
      end
    end
  end
end
