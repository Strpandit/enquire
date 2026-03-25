class AdminUser < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :validatable, :trackable
end
