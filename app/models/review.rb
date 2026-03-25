class Review < ApplicationRecord
  belongs_to :account
  belongs_to :business_profile

  validates :rating, inclusion: { in: 1..5 }
  validates :comment, length: { maximum: 500 }, allow_blank: true
  validates :account_id, uniqueness: { scope: :business_profile_id, message: "has already reviewed this business" }
  validate :only_for_approved_business_profiles

  after_commit :update_business_rating

  private

  def update_business_rating
    bp = business_profile

    avg = bp.reviews.average(:rating)&.to_f || 0.0
    count = bp.reviews.count

    bp.update_columns(
      avg_rating: avg.round(1),
      reviews_count: count
    )
  end

  def only_for_approved_business_profiles
    return if business_profile&.approved?

    errors.add(:business_profile, "must be approved before reviews can be added")
  end
end
