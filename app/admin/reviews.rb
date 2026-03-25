ActiveAdmin.register Review do
  actions :index, :show, :destroy

  index do
    selectable_column
    id_column
    column(:business_profile) { |review| review.business_profile.business_name }
    column(:account) { |review| review.account.full_name }
    column :rating
    column :comment
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row(:business_profile) { |review| review.business_profile.business_name }
      row(:account) { |review| review.account.full_name }
      row :rating
      row :comment
      row :created_at
      row :updated_at
    end
  end

  filter :business_profile_business_name, as: :string, label: "Business Profile"
  filter :account_full_name, as: :string, label: "Account Name"
end