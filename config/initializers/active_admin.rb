ActiveAdmin.setup do |config|
  config.site_title = "Preview Tax Admin"
  config.site_title_image = "preview-tax-logo-cropped.png"
  config.default_namespace = :admin
  config.authentication_method = :authenticate_admin_user!
  config.current_user_method = :current_admin_user
  config.logout_link_path = :destroy_admin_user_session_path
  config.batch_actions = true
  config.comments = false
  config.favicon = false
  meta_tags_options = { viewport: "width=device-width, initial-scale=1" }
  config.meta_tags = meta_tags_options
  config.meta_tags_for_logged_out_pages = meta_tags_options

  config.namespace :admin do |admin|
    admin.build_menu do |menu|
      menu.add label: "Dashboard", priority: 0, url: proc { admin_root_path }
    end
  end
end
