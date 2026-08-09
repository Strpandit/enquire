ActiveAdmin.register ChatSession do
  actions :index, :show

  index do
    id_column
    column(:customer) { |sess| sess.customer_account&.full_name }
    column(:business) { |sess| sess.business_profile&.business_name }
    column :status
    column("Price / Min") { |sess| "₹#{sess.price_per_minute_cents / 100.0}" }
    column :billed_minutes
    column("Total Charged") { |sess| "₹#{sess.total_amount_cents / 100.0}" }
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row(:customer) { |sess| sess.customer_account&.full_name }
      row(:business) { |sess| sess.business_profile&.business_name }
      row :status
      row("Price Per Minute") { |sess| "₹#{sess.price_per_minute_cents / 100.0}" }
      row :billable_seconds
      row :billed_minutes
      row("Total Amount Charged") { |sess| "₹#{sess.total_amount_cents / 100.0}" }
      row :end_reason
      row :requested_at
      row :started_at
      row :ended_at
      row :created_at
    end
  end

  filter :status
  filter :customer_account_full_name, as: :string, label: "Customer Name"
  filter :business_profile_business_name, as: :string, label: "Business Name"
  filter :created_at
end
