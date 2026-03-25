ActiveAdmin.register BusinessProfile do
  actions :index, :show, :destroy

  action_item :approve_profile, only: :show, if: proc { resource.pending? || resource.rejected? } do
    link_to "Approve Profile", approve_admin_business_profile_path(resource), method: :patch
  end

  action_item :reject_profile, only: :show, if: proc { resource.pending? } do
    link_to "Reject Profile", reject_admin_business_profile_path(resource), method: :patch
  end

  member_action :approve, method: :patch do
    ActiveRecord::Base.transaction do
      resource.update!(approval_status: :approved, approved_at: Time.current, rejection_reason: nil)
      resource.account.update!(is_business: true)
      AccountAuthMailer.approval_email(resource.account, resource.approved_at).deliver_later
    end
    redirect_to resource_path, notice: "Business profile approved"
  end

  member_action :reject, method: :patch do
    ActiveRecord::Base.transaction do
      resource.update!(approval_status: :rejected, approved_at: nil, rejection_reason: "Rejected by admin")
      resource.account.update!(is_business: false)
      AccountAuthMailer.rejection_email(resource.account, resource.rejection_reason).deliver_later
    end
    redirect_to resource_path, alert: "Business profile rejected"
  end

  index do
    selectable_column
    id_column
    column :business_name
    column(:account) { |profile| profile.account&.full_name }
    column :approval_status
    column :is_available
    column :is_verified
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :business_name
      row(:account) { |profile| profile.account&.full_name }
      row :approval_status
      row :rejection_reason
      row :approved_at
      row :bio
      row :about
      row :business_address
      row :chat_price
      row :call_price
      row :v_call_price
      row :is_available
      row :is_verified
      row :gst_enabled
      row :gst_number
      row :state
      row :city
      row :pincode
      row :share_token
      row(:gst_certificate) do |profile|
        profile.gst_certificate.attached? ? link_to(profile.gst_certificate.filename.to_s, url_for(profile.gst_certificate)) : "Not uploaded"
      end
      row :created_at
      row :updated_at
    end

    panel "Categories" do
      table_for business_profile.categories do
        column :name
        column :created_at
      end
    end

    panel "Schedules" do
      table_for business_profile.schedules do
        column :availability_type
        column :day_of_week do |schedule|
          schedule.day_of_week.nil? ? "Always" : Date::DAYNAMES[schedule.day_of_week]
        end
        column(:start_time) { |schedule| schedule.start_time&.strftime("%I:%M %p") }
        column(:end_time) { |schedule| schedule.end_time&.strftime("%I:%M %p") }
      end
    end
  end

  filter :business_name
  filter :account_full_name, as: :string, label: "Account Name"
  filter :approval_status
  filter :is_available
  filter :is_verified
  filter :gst_enabled
  filter :state
  filter :city
end
