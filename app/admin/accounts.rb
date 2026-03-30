ActiveAdmin.register Account do
  actions :index, :show, :destroy

  action_item :approve_verification, only: :show, if: proc { resource.pending? || resource.rejected? } do
    link_to "Approve Verification", approve_verification_admin_account_path(resource), method: :patch
  end

  action_item :reject_verification, only: :show, if: proc { resource.pending? } do
    link_to "Reject Verification", reject_verification_admin_account_path(resource), method: :patch
  end

  member_action :approve_verification, method: :patch do
    resource.update!(verification_status: :approved, verified_at: Time.current, verification_rejection_reason: nil)
    Notifications::Creator.call(
      recipient: resource,
      notifiable: resource,
      notification_type: "verification_approved",
      title: "Verification approved",
      body: "Your account verification has been approved.",
      payload: { verification_status: resource.verification_status }
    )
    redirect_to resource_path, notice: "Account verification approved"
  end

  member_action :reject_verification, method: :patch do
    resource.update!(verification_status: :rejected, verified_at: nil, verification_rejection_reason: "Rejected by admin")
    Notifications::Creator.call(
      recipient: resource,
      notifiable: resource,
      notification_type: "verification_rejected",
      title: "Verification rejected",
      body: resource.verification_rejection_reason.presence || "Your account verification was rejected.",
      payload: { verification_status: resource.verification_status, rejection_reason: resource.verification_rejection_reason }
    )
    redirect_to resource_path, alert: "Account verification rejected"
  end

  index do
    selectable_column
    id_column
    column :full_name
    column :email
    column :phone
    column :username
    column :is_business
    column :verification_status
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :full_name
      row :email
      row :phone
      row :username
      row :state
      row :district
      row :city
      row :pincode
      row :is_business
      row :verification_status
      row :verification_rejection_reason
      row :verified_at
      row(:languages) { |account| account.languages.join(", ") }
      row(:profile_pic) do |account|
        account.profile_pic.attached? ? link_to(account.profile_pic.filename.to_s, url_for(account.profile_pic)) : "Not uploaded"
      end
      row(:pan_card) do |account|
        account.pan_card.attached? ? link_to(account.pan_card.filename.to_s, url_for(account.pan_card)) : "Not uploaded"
      end
      row(:aadhaar_card) do |account|
        account.aadhaar_card.attached? ? link_to(account.aadhaar_card.filename.to_s, url_for(account.aadhaar_card)) : "Not uploaded"
      end
      row(:passport_photo) do |account|
        account.passport_photo.attached? ? link_to(account.passport_photo.filename.to_s, url_for(account.passport_photo)) : "Not uploaded"
      end
    end
  end

  filter :full_name
  filter :email
  filter :phone
  filter :username
  filter :is_business
  filter :verification_status
  filter :created_at
  filter :state
  filter :district
  filter :city
  filter :pincode
end
