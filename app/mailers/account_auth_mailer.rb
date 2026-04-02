class AccountAuthMailer < ApplicationMailer
  default from: "Preview Tax <chaturvedisingham007@gmail.com>"

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
end