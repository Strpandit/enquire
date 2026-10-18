class AdminNotificationMailer < ApplicationMailer
  default from: "Preview Tax Security <support@previewtax.com>"

  def contact_sharing_alert(sender_id:, recipient_id:, conversation_id:, session_id:, content:, reasons:, shared_at_iso: nil)
    @sender = Account.find_by(id: sender_id)
    @recipient = Account.find_by(id: recipient_id)
    @conversation_id = conversation_id
    @session_id = session_id
    @content = content
    @reasons = Array(reasons)
    parsed_time = shared_at_iso.present? ? (Time.zone.parse(shared_at_iso.to_s) rescue nil) : nil
    @shared_at = (parsed_time || Time.current).strftime("%B %d, %Y at %I:%M %p %Z")

    admin_recipients = AdminUser.pluck(:email).compact.reject(&:blank?)
    default_admin = ENV.fetch("ADMIN_EMAIL", "previewtaxinc@gmail.com")
    admin_recipients << default_admin if default_admin.present?
    admin_recipients = admin_recipients.uniq

    return if admin_recipients.empty?

    sender_name = @sender&.full_name.presence || "Account ##{sender_id}"
    recipient_name = @recipient&.full_name.presence || "Account ##{recipient_id}"

    mail(
      to: admin_recipients,
      subject: "🚨 Policy Alert: Contact details shared in chat by #{sender_name} with #{recipient_name}"
    )
  end

  # Sent to admins when an expert submits (or resubmits) a business profile for review.
  def business_profile_review_request(business_profile_id:, kind: "new")
    @business_profile = BusinessProfile.includes(:account, :categories).find_by(id: business_profile_id)
    return if @business_profile.nil?

    @account = @business_profile.account
    @kind = kind.to_s # "new" | "resubmitted" | "updated"
    @submitted_at = Time.current.strftime("%B %d, %Y at %I:%M %p %Z")
    @review_url = admin_review_url(:admin_business_profile_url, @business_profile)

    recipients = admin_recipients
    return if recipients.empty?

    label = { "new" => "New expert profile", "resubmitted" => "Expert profile resubmitted", "updated" => "Expert profile changed" }.fetch(@kind, "Expert profile")
    mail(to: recipients, subject: "[Action needed] #{label} awaiting review - #{@account.full_name}")
  end

  # Sent to admins when an expert applies for the verification (orange) badge.
  def verification_review_request(account_id:, payment: {})
    @account = Account.find_by(id: account_id)
    return if @account.nil?

    @payment = (payment || {}).with_indifferent_access
    @submitted_at = Time.current.strftime("%B %d, %Y at %I:%M %p %Z")
    @business_profile = @account.business_profile
    @review_url = admin_review_url(:admin_account_url, @account)

    recipients = admin_recipients
    return if recipients.empty?

    mail(to: recipients, subject: "[Action needed] Verification badge request - #{@account.full_name}")
  end

  private

  def admin_recipients
    recipients = AdminUser.pluck(:email).compact.reject(&:blank?)
    default_admin = ENV.fetch("ADMIN_EMAIL", "previewtaxinc@gmail.com")
    recipients << default_admin if default_admin.present?
    recipients.uniq
  end

  def admin_review_url(helper, record)
    Rails.application.routes.url_helpers.public_send(helper, record)
  rescue StandardError
    nil
  end
end
