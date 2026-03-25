class BusinessProfileCategory < ApplicationRecord
  belongs_to :category
  belongs_to :business_profile

  validates :category_id, uniqueness: { scope: :business_profile_id }
end
