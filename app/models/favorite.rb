class Favorite < ApplicationRecord
  belongs_to :account
  belongs_to :business_profile, counter_cache: false

  validates :account_id, uniqueness: { scope: :business_profile_id }
end
