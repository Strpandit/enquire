if Rails.env.development?
  Bullet.enable = true
  Bullet.rails_logger = true
  Bullet.console = true
  Bullet.add_footer = false
  Bullet.raise = false
end
