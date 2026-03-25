class Category < ApplicationRecord
  has_many :business_profile_categories, dependent: :destroy
  has_many :business_profiles, through: :business_profile_categories

  before_validation :normalize_name

  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { minimum: 2, maximum: 80 }

  private

  def normalize_name
    self.name = name.to_s.strip.squish
  end
end
