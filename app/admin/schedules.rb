ActiveAdmin.register Schedule do

  actions :index, :show, :destroy

  index do
    selectable_column
    id_column
    column(:account) { |schedule| schedule.business_profile.account.full_name }
    column :availability_type
    column :day_of_week
    column :start_time
    column :end_time
    actions
  end

  show do
    attributes_table do
      row :id
      row(:account) { |schedule| schedule.business_profile.account.full_name }
      row :availability_type
      row :day_of_week
      row :start_time
      row :end_time
      row :created_at
      row :updated_at
    end
  end
end
