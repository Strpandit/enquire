ActiveAdmin.register DeviceSession do
  menu priority: 3, label: "Device Sessions"

  actions :index, :show

  filter :ip_address
  filter :network_type
  filter :app_version
  filter :android_version
  filter :login_at
  filter :last_seen_at

  index do
    selectable_column
    id_column
    column("User Account") { |session| session.account ? link_to(session.account.full_name || session.account.email, admin_account_path(session.account)) : "Guest" }
    column("Device") { |session| session.device ? link_to("#{session.device.manufacturer} #{session.device.model}", admin_device_path(session.device)) : "N/A" }
    column("Server IP", :ip_address)
    column :network_type
    column :app_version
    column :android_version
    column :login_at
    column :last_seen_at
    column("Status") { |session| session.logout_at ? status_tag("Closed", class: "red") : status_tag("Active", class: "green") }
    actions
  end
end
