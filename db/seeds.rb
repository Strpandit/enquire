AdminUser.find_or_create_by!(email: ENV.fetch("ADMIN_EMAIL", "previewtaxinc@gmail.com")) do |admin|
  admin.password = ENV.fetch("ADMIN_PASSWORD", "Admin@2026")
  admin.password_confirmation = admin.password
end
