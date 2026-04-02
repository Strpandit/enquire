class Schedule < ApplicationRecord
  belongs_to :business_profile

  enum :availability_type, { custom: 0, always: 1 }
  DAY_NAME_TO_INDEX = {
    "sunday" => 0,
    "monday" => 1,
    "tuesday" => 2,
    "wednesday" => 3,
    "thursday" => 4,
    "friday" => 5,
    "saturday" => 6
  }.freeze

  validates :availability_type, presence: true
  validates :day_of_week, inclusion: { in: 0..6, message: "must be between 0 and 6" }, allow_nil: true
  validates :day_of_week, :start_time, :end_time, presence: true, if: :custom?

  before_validation :normalize_day_of_week

  validate :only_one_always
  validate :no_overlap
  validate :end_time_after_start_time, if: :custom?

  def start_time=(value)
    super(normalize_clock_value(value))
  end

  def end_time=(value)
    super(normalize_clock_value(value))
  end

  def covers_time?(time)
    return false unless custom? && start_time.present? && end_time.present?

    current_seconds = seconds_since_midnight(time)
    current_seconds >= seconds_since_midnight(start_time) &&
      current_seconds < seconds_since_midnight(end_time)
  end

  private

  def normalize_day_of_week
    return if day_of_week.blank?

    normalized_value =
      case day_of_week
      when Integer
        day_of_week
      else
        value = day_of_week.to_s.strip.downcase
        numeric_value = Integer(value, exception: false)
        numeric_value.nil? ? DAY_NAME_TO_INDEX[value] : numeric_value
      end

    self.day_of_week = normalized_value
  end

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

  def normalize_clock_value(value)
    return if value.blank?
    return value if value.is_a?(Time)

    if value.respond_to?(:hour) && value.respond_to?(:min)
      return Time.zone.local(2000, 1, 1, value.hour, value.min, value.try(:sec).to_i)
    end

    parsed = Time.zone.parse("2000-01-01 #{value}")
    return parsed if parsed.present?

    value
  rescue ArgumentError
    value
  end

  def seconds_since_midnight(value)
    value.hour * 3600 + value.min * 60 + value.sec
  end
end
