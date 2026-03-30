class ProfilesController < ActionController::Base
  def show
    business_profile = BusinessProfile.find_by!(share_token: params[:share_token], approval_status: :approved)
    redirect_to "enquire://business_profiles/#{business_profile.account.uid}?share_token=#{business_profile.share_token}", allow_other_host: true
  end
end
