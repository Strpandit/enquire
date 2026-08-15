ActiveAdmin.register Account do
  actions :index, :show, :destroy

  action_item :approve_verification, only: :show, if: proc { resource.pending? || resource.rejected? || !resource.is_verified? } do
    link_to "Approve Verification", approve_verification_admin_account_path(resource), method: :patch
  end

  action_item :reject_verification, only: :show, if: proc { resource.pending? || resource.approved? } do
    link_to "Reject Verification", reject_verification_admin_account_path(resource), method: :patch
  end

  member_action :approve_verification, method: :patch do
    resource.update!(
      verification_status: :approved,
      is_verified: true,
      verified_at: Time.current,
      verification_rejection_reason: nil
    )
    Notifications::Creator.call(
      recipient: resource,
      notifiable: resource,
      notification_type: "verification_approved",
      title: "Verification approved",
      body: "Your account verification has been approved.",
      payload: { verification_status: resource.verification_status, is_verified: true }
    )
    redirect_to resource_path, notice: "Account verification approved & verified badge enabled!"
  end

  member_action :reject_verification, method: :patch do
    resource.update!(
      verification_status: :rejected,
      is_verified: false,
      verified_at: nil,
      verification_rejection_reason: "Rejected by admin"
    )
    Notifications::Creator.call(
      recipient: resource,
      notifiable: resource,
      notification_type: "verification_rejected",
      title: "Verification rejected",
      body: resource.verification_rejection_reason.presence || "Your account verification was rejected.",
      payload: { verification_status: resource.verification_status, is_verified: false, rejection_reason: resource.verification_rejection_reason }
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
    column :is_verified
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
      row :is_verified
      row :verification_rejection_reason
      row :verified_at
      row :verification_expires_at
      row :days_remaining
      row(:languages) { |account| account.languages.join(", ") }
      row(:profile_pic) do |account|
        if account.profile_pic.attached?
          link_to(account.profile_pic.filename.to_s, url_for(account.profile_pic), target: "_blank")
        else
          "Not uploaded"
        end
      end
      row(:pan_card) do |account|
        if account.pan_card.attached?
          link_to(account.pan_card.filename.to_s, url_for(account.pan_card), target: "_blank")
        else
          "Not uploaded"
        end
      end
      row(:aadhaar_card) do |account|
        if account.aadhaar_card.attached?
          link_to(account.aadhaar_card.filename.to_s, url_for(account.aadhaar_card), target: "_blank")
        else
          "Not uploaded"
        end
      end
      row(:aadhaar_card_back) do |account|
        if account.respond_to?(:aadhaar_card_back) && account.aadhaar_card_back.attached?
          link_to(account.aadhaar_card_back.filename.to_s, url_for(account.aadhaar_card_back), target: "_blank")
        else
          "Not uploaded"
        end
      end
      row(:passport_photo) do |account|
        if account.passport_photo.attached?
          link_to(account.passport_photo.filename.to_s, url_for(account.passport_photo), target: "_blank")
        else
          "Not uploaded"
        end
      end
      row(:education_documents) do |account|
        if account.respond_to?(:education_documents) && account.education_documents.attached?
          ul do
            account.education_documents.each do |doc|
              li { link_to(doc.filename.to_s, url_for(doc), target: "_blank") }
            end
          end
        else
          "Not uploaded"
        end
      end
    end
  end

  filter :full_name
  filter :email
  filter :phone
  filter :username
  filter :is_business
  filter :verification_status
  filter :is_verified
  filter :created_at
  filter :state
  filter :district
  filter :city
  filter :pincode
end
