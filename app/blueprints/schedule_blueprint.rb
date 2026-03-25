class ScheduleBlueprint < Blueprinter::Base
  identifier :id

  fields :business_profile_id, :availability_type, :day_of_week

  field :start_time do |schedule|
    schedule.start_time&.strftime("%H:%M")
  end

  field :end_time do |schedule|
    schedule.end_time&.strftime("%H:%M")
  end
end
