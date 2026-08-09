ActiveAdmin.register Favorite do
  actions :index, :show, :destroy

  index do
    id_column
    column(:account) { |fav| fav.account&.full_name }
    column(:business_profile) { |fav| fav.business_profile&.business_name }
    column :created_at
    actions
  end

  filter :account_full_name, as: :string, label: "User Name"
  filter :business_profile_business_name, as: :string, label: "Business Name"
end
