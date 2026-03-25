class ReviewBlueprint < Blueprinter::Base
  identifier :id

  fields :business_profile_id, :account_id, :rating, :comment, :created_at

  field :reviewer_name do |review|
    review.account.full_name
  end

  field :reviewer_username do |review|
    review.account.username
  end
end
