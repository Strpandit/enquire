ActiveAdmin.register CallHistory do
  actions :index, :show

  index do
    id_column
    column(:caller) { |call| call.caller_account&.full_name }
    column(:receiver) { |call| call.receiver_account&.full_name }
    column :call_type
    column("Duration (sec)") { |call| "#{call.duration_seconds}s" }
    column("Amount Charged") { |call| "₹#{call.amount_charged_cents / 100.0}" }
    column :status
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row(:caller) { |call| call.caller_account&.full_name }
      row(:receiver) { |call| call.receiver_account&.full_name }
      row :call_type
      row :channel_name
      row("Duration") { |call| "#{call.duration_seconds} seconds" }
      row("Amount Charged") { |call| "₹#{call.amount_charged_cents / 100.0}" }
      row :status
      row :end_reason
      row :started_at
      row :ended_at
      row :created_at
    end
  end

  filter :call_type
  filter :status
  filter :caller_account_full_name, as: :string, label: "Caller Name"
  filter :receiver_account_full_name, as: :string, label: "Receiver Name"
  filter :created_at
end
