class Favorite < ApplicationRecord
  belongs_to :account
  belongs_to :business_profile, counter_cache: false

  validates :account_id, uniqueness: { scope: :business_profile_id }
  validate :cannot_favorite_own_business

  private

  def cannot_favorite_own_business
    return if account_id.blank? || business_profile.blank?
    return unless business_profile.account_id == account_id

    errors.add(:business_profile, "cannot belong to your own account")
  end
end
