class CreateSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :schedules do |t|
      t.references :business_profile, null: false, foreign_key: true
      t.integer :day_of_week
      t.time :start_time
      t.time :end_time
      t.integer :availability_type, default: 0

      t.timestamps
    end
  end
end
