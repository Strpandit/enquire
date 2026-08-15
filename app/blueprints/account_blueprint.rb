class AccountBlueprint < Blueprinter::Base
  identifier :id

  fields :uid, :full_name, :username, :email, :phone, :state, :district, :city, :pincode, :languages, :is_business, :verification_status, :verified_at, :verification_expires_at, :days_remaining

  field :is_verified do |account|
    account.is_verified?
  end

  field :wallet_balance_cents do |account, options|
    (options[:include_private] || options[:viewer]&.id == account.id) ? account.wallet_balance_cents : nil
  end

  field :earnings_balance_cents do |account, options|
    (options[:include_private] || options[:viewer]&.id == account.id) ? account.earnings_balance_cents : nil
  end

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
    (options[:include_private] || options[:viewer]&.id == account.id) ? account.verification_rejection_reason : nil
  end

  field :verification_documents do |account, options|
    is_owner = options[:viewer] && options[:viewer].id == account.id
    next unless options[:include_private] || is_owner || options[:include_verification_documents]

    {
      pan_card_url: account.pan_card.attached? ? Rails.application.routes.url_helpers.url_for(account.pan_card) : nil,
      aadhaar_card_url: account.aadhaar_card.attached? ? Rails.application.routes.url_helpers.url_for(account.aadhaar_card) : nil,
      aadhaar_card_back_url: account.respond_to?(:aadhaar_card_back) && account.aadhaar_card_back.attached? ? Rails.application.routes.url_helpers.url_for(account.aadhaar_card_back) : nil,
      passport_photo_url: account.passport_photo.attached? ? Rails.application.routes.url_helpers.url_for(account.passport_photo) : nil,
      education_documents_urls: account.respond_to?(:education_documents) && account.education_documents.attached? ? account.education_documents.map { |doc| Rails.application.routes.url_helpers.url_for(doc) } : []
    }
  end

  association :business_profile, blueprint: BusinessProfileBlueprint, if: ->(_field_name, _account, options) { options[:include_business] }
end