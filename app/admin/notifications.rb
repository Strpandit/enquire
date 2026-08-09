ActiveAdmin.register Notification do
  actions :index, :show

  index do
    id_column
    column(:recipient) { |notif| notif.recipient_account&.full_name }
    column :notification_type
    column :title
    column :body
    column :read_at
    column :created_at
    actions
  end

  filter :notification_type
  filter :recipient_account_full_name, as: :string, label: "Recipient Name"
  filter :title
  filter :created_at
end
