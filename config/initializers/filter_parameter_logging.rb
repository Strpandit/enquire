# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :phone, :full_name, :name, :aadhaar, :aadhar, :pan, :pan_card, :aadhaar_card,
  :address, :business_address, :pincode, :gst_number, :device_token,
  :signature, :authorization, :password_digest
]
