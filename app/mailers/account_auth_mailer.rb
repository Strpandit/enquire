class AccountAuthMailer < ApplicationMailer
  default from: "Preview Tax <support@previewtax.com>"

  def forgot_password_otp(user)
    @user = user
    @otp = user.otp_pin
    @expires_in_minutes = 5
    mail(to: @user.email, subject: "Password Reset OTP - Preview Tax")
  end

  def password_reset_confirmation(user)
    @user = user
    @reset_time = Time.now.strftime("%B %d, %Y at %I:%M %p")
    mail(to: @user.email, subject: "Password Reset Confirmation - Preview Tax")
  end

  def welcome_email(user)
    @user = user
    mail(to: @user.email, subject: "Welcome to Preview Tax - Your Business Profile Created")
  end

  def approval_email(user, approved_at)
    @user = user
    @approved_at = approved_at
    mail(to: @user.email, subject: "🎉 Your Preview Tax Business Profile is Approved!")
  end

  def rejection_email(user, reason = nil)
    @user = user
    @rejection_reason = reason
    mail(to: @user.email, subject: "Your Preview Tax Business Profile Status Update")
  end

  def profile_submitted_email(user, kind = "new")
    @user = user
    @kind = kind.to_s
    @submitted_at = Time.current.strftime("%B %d, %Y at %I:%M %p %Z")
    subject = @kind == "new" ? "Your Preview Tax expert profile has been submitted for review" : "Your Preview Tax expert profile is back in review"
    mail(to: @user.email, subject: subject)
  end

  def verification_submitted_email(user, payment = {})
    @user = user
    @payment = (payment || {}).with_indifferent_access
    @submitted_at = Time.current.strftime("%B %d, %Y at %I:%M %p %Z")
    mail(to: @user.email, subject: "Verification badge request received - Preview Tax")
  end

  def verification_approved_email(user, verified_at, expires_at)
    @user = user
    @verified_at = verified_at
    @expires_at = expires_at
    mail(to: @user.email, subject: "Your Preview Tax verification badge is active")
  end
end
