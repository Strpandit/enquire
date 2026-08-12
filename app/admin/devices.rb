ActiveAdmin.register Device do
  menu priority: 2, label: "Devices"

  actions :index, :show

  filter :device_uuid
  filter :manufacturer
  filter :model
  filter :android_version
  filter :app_version
  filter :network_type
  filter :last_ip
  filter :last_seen_at

  index do
    selectable_column
    id_column
    column("User") { |device| device.account ? link_to(device.account.full_name || device.account.email, admin_account_path(device.account)) : "Guest" }
    column :manufacturer
    column :model
    column("Android OS") { |device| "Android #{device.android_version} (API #{device.android_api_level})" }
    column("App Ver (Build)") { |device| "#{device.app_version} (#{device.app_build})" }
    column :network_type
    column("Server-Observed IP", :last_ip)
    column :last_seen_at
    actions
  end

  show title: ->(device) { "#{device.manufacturer} #{device.model} (#{device.device_uuid[0..8]}...)" } do
    attributes_table do
      row :id
      row("User Account") { |device| device.account ? link_to(device.account.full_name || device.account.email, admin_account_path(device.account)) : "Guest" }
      row :device_uuid
      row :manufacturer
      row :model
      row :android_version
      row :android_api_level
      row :app_version
      row :app_build
      row :network_type
      row("Server Observed IP", &:last_ip)
      row :push_token
      row :first_seen_at
      row :last_seen_at
      row :created_at
      row :updated_at
    end

    panel "Associated User Sessions" do
      table_for device.device_sessions.order(created_at: :desc).limit(10) do
        column :id
        column("User") { |s| s.account ? link_to(s.account.full_name, admin_account_path(s.account)) : "N/A" }
        column("Server IP", &:ip_address)
        column :network_type
        column :login_at
        column :last_seen_at
        column :logout_at
      end
    end

    panel "Recent Activity Logs on this Device" do
      table_for device.activity_logs.order(created_at: :desc).limit(15) do
        column("Time") { |log| log.created_at.strftime("%d %b %Y, %I:%M %p") }
        column("Event") { |log| status_tag(log.event) }
        column :title
        column("Server IP", &:ip_address)
        column :metadata
      end
    end
  end
end
