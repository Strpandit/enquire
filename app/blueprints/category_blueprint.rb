class CategoryBlueprint < Blueprinter::Base
  identifier :id

  fields :name

  field :business_profiles_count do |category|
    category.business_profiles.approved.count
  end
end
