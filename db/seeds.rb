AdminUser.find_or_create_by!(email: ENV.fetch("ADMIN_EMAIL", "admin@enquire.com")) do |admin|
  admin.password = ENV.fetch("ADMIN_PASSWORD", "Pass@123")
  admin.password_confirmation = admin.password
end
