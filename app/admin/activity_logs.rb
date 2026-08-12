ActiveAdmin.register ActivityLog do
  menu priority: 4, label: "Activity Logs"

  actions :index, :show

  filter :event
  filter :title
  filter :ip_address
  filter :created_at

  index do
    selectable_column
    id_column
    column("User Account") { |log| log.account ? link_to(log.account.full_name || log.account.email, admin_account_path(log.account)) : "Guest" }
    column("Device") { |log| log.device ? link_to("#{log.device.manufacturer} #{log.device.model}", admin_device_path(log.device)) : "N/A" }
    column("Event") { |log| status_tag(log.event) }
    column :title
    column("Server IP", :ip_address)
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row("User Account") { |log| log.account ? link_to(log.account.full_name || log.account.email, admin_account_path(log.account)) : "Guest" }
      row("Device") { |log| log.device ? link_to("#{log.device.manufacturer} #{log.device.model}", admin_device_path(log.device)) : "N/A" }
      row :event
      row :title
      row("Server Observed IP", &:ip_address)
      row("Metadata JSON") { |log| pre JSON.pretty_generate(log.metadata || {}) }
      row :created_at
      row :updated_at
    end
  end
end
