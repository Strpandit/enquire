class BusinessProfileBlueprint < Blueprinter::Base
  identifier :id

  fields :account_id, :business_name, :business_address, :bio, :about, :chat_price, :call_price, :v_call_price,
         :is_available, :gst_enabled, :gst_number, :state, :city, :pincode, :avg_rating,
         :reviews_count, :approval_status

  field :currently_available do |bp|
    bp.currently_available?
  end

  field :rejection_reason do |bp, options|
    viewer = options[:viewer]
    viewer && viewer.id == bp.account_id ? bp.rejection_reason : nil
  end

  field :verified_badge do |bp|
    bp.account.is_verified?
  end

  field :favorite do |bp, options|
    viewer = options[:viewer]
    viewer.present? && viewer.favorite_business_profiles.exists?(bp.id)
  end

  field :share_url do |bp, options|
    host = options[:host]
    next if host.blank?

    Rails.application.routes.url_helpers.public_expert_url(bp.account.uid, host: host)
  end

  field :deep_link_url do |bp|
    "previewtax://expert/#{bp.account.uid}"
  end

  field :gst_certificate_url do |bp|
    bp.gst_certificate.attached? ? Rails.application.routes.url_helpers.url_for(bp.gst_certificate) : nil
  end

  field :gst_certificate do |bp|
    bp.gst_certificate_details
  end

  association :categories, blueprint: CategoryBlueprint
  association :schedules, blueprint: ScheduleBlueprint
  association :reviews, blueprint: ReviewBlueprint
  association :account, blueprint: AccountBlueprint, if: ->(_field_name, _bp, options) { options[:include_account] }
end