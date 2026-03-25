module Api
  module V1
    class SchedulesController < BaseController
      before_action :ensure_business_profile!
      before_action :set_schedule, only: [ :show, :update, :destroy ]
      before_action :ensure_owner!, only: [ :show, :update, :destroy ]

      def index
        schedules = current_business_profile.schedules.order(:day_of_week, :start_time)
        render json: { schedule: ScheduleBlueprint.render_as_hash(schedules) }, status: :ok
      end

      def show
        render json: { schedule: ScheduleBlueprint.render_as_hash(@schedule) }, status: :ok
      end

      def create
        if schedule_params[:availability_type] == "always"
          current_business_profile.schedules.destroy_all

          schedule = current_business_profile.schedules.create!(
            availability_type: "always"
          )

          return render json: {
            message: "Always available set",
            schedule: ScheduleBlueprint.render_as_hash(schedule)
          }, status: :created
        end

        schedule = current_business_profile.schedules.create!(schedule_params)

        render json: {
          message: "Schedule created successfully",
          schedule: ScheduleBlueprint.render_as_hash(schedule)
        }, status: :created
      end

      def bulk_create
        schedules = params[:schedules].map do |slot|
          current_business_profile.schedules.create!(
            day_of_week: slot[:day],
            start_time: slot[:start_time],
            end_time: slot[:end_time],
            availability_type: "custom"
          )
        end

        render json: {
          schedules: ScheduleBlueprint.render_as_hash(schedules)
        }, status: :created
      end

      def update
        @schedule.update!(schedule_params)

        render json: {
          message: "Schedule updated successfully",
          schedule: ScheduleBlueprint.render_as_hash(@schedule)
        }, status: :ok
      end

      def destroy
        @schedule.destroy!
        render json: { message: "Schedule deleted successfully" }, status: :ok
      end

      private

      def ensure_business_profile!
        return if current_account.business_profile.present?

        render json: {
          errors: ["Create business profile first"]
        }, status: :unprocessable_entity
      end

      def set_schedule
        @schedule = Schedule.find_by(id: params[:id])
      end

      def ensure_owner!
        return if @schedule.business_profile_id == current_business_profile.id

        render json: { errors: [ "You are not allowed to modify this schedule" ] }, status: :forbidden
      end

      def schedule_params
        params.require(:schedule).permit(:day_of_week, :start_time, :end_time, :availability_type)
      end

      def current_business_profile
        current_account.business_profile
      end
    end
  end
end
