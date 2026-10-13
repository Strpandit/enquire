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
end
