class AccountBlueprint < Blueprinter::Base
  identifier :id

  fields :uid, :full_name, :email, :phone, :username, :state, :district, :city, :pincode, :languages, :is_business, :is_verified, :verification_status, :wallet_balance_cents

  field :profile_pic_url do |account|
    account.profile_pic.attached? ? Rails.application.routes.url_helpers.url_for(account.profile_pic) : nil
  end

  field :profile_pic do |account|
    account.profile_pic_details
  end

  field :verified_badge do |account|
    account.is_verified?
  end

  field :verification_rejection_reason do |account, options|
    options[:include_private] ? account.verification_rejection_reason : nil
  end

  field :verification_documents do |account, options|
    next unless options[:include_private]

    {
      pan_card_url: account.pan_card.attached? ? Rails.application.routes.url_helpers.url_for(account.pan_card) : nil,
      aadhaar_card_url: account.aadhaar_card.attached? ? Rails.application.routes.url_helpers.url_for(account.aadhaar_card) : nil,
      passport_photo_url: account.passport_photo.attached? ? Rails.application.routes.url_helpers.url_for(account.passport_photo) : nil
    }
  end

  association :business_profile, blueprint: BusinessProfileBlueprint, if: ->(_field_name, _account, options) { options[:include_business] }
end