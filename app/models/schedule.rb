class Schedule < ApplicationRecord
  belongs_to :business_profile

  enum :availability_type, { custom: 0, always: 1 }

  validates :availability_type, presence: true
  validates :day_of_week, inclusion: { in: 0..6, message: "must be between 0 and 6" }, allow_nil: true
  validates :day_of_week, :start_time, :end_time, presence: true, if: :custom?

  validate :only_one_always
  validate :no_overlap
  validate :end_time_after_start_time, if: :custom?

  private

  def only_one_always
    return unless always?

    if business_profile.schedules.where(availability_type: "always").where.not(id: id).exists?
      errors.add(:base, "Only one 'always available' allowed")
    end
  end

  def no_overlap
    return unless custom?

    overlapping = business_profile.schedules
      .where(day_of_week: day_of_week)
      .where.not(id: id)
      .where("start_time < ? AND end_time > ?", end_time, start_time)

    if overlapping.exists?
      errors.add(:base, "Time slot overlaps with existing schedule")
    end
  end

  def end_time_after_start_time
    return if start_time.blank? || end_time.blank?
    return if end_time > start_time

    errors.add(:end_time, "must be after start time")
  end
end
