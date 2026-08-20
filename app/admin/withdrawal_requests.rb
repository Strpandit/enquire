ActiveAdmin.register WithdrawalRequest do
  actions :index, :show

  scope :all, default: true
  scope :pending
  scope :approved
  scope :completed
  scope :rejected

  action_item :approve_payout, only: :show, if: proc { resource.pending? } do
    link_to "Approve & Mark Paid", approve_payout_admin_withdrawal_request_path(resource), method: :patch, data: { confirm: "Confirm payout approval? Net amount will be sent to #{resource.upi_id}" }
  end

  action_item :reject_payout, only: :show, if: proc { resource.pending? } do
    link_to "Reject & Refund", reject_payout_admin_withdrawal_request_path(resource), method: :patch, data: { confirm: "Reject payout request and refund earnings balance to expert?" }
  end

  member_action :approve_payout, method: :patch do
    ActiveRecord::Base.transaction do
      resource.update!(
        status: :completed,
        approved_at: Time.current,
        completed_at: Time.current
      )

      Notifications::Creator.call(
        recipient: resource.account,
        actor: current_admin_user,
        notifiable: resource,
        notification_type: "withdrawal_approved",
        title: "Withdrawal Approved & Paid 🎉",
        body: "Your payout of ₹#{resource.net_amount} has been processed to #{resource.upi_id}.",
        payload: { withdrawal_id: resource.id, upi_id: resource.upi_id, net_amount: resource.net_amount }
      )
    end

    redirect_to resource_path, notice: "Withdrawal approved and marked completed!"
  end

  member_action :reject_payout, method: :patch do
    ActiveRecord::Base.transaction do
      resource.update!(
        status: :rejected,
        failure_reason: "Rejected by admin"
      )

      resource.account.update!(
        earnings_balance_cents: resource.account.earnings_balance_cents + resource.amount_cents
      )

      Notifications::Creator.call(
        recipient: resource.account,
        actor: current_admin_user,
        notifiable: resource,
        notification_type: "withdrawal_rejected",
        title: "Withdrawal Request Status Update",
        body: "Your withdrawal request for ₹#{resource.amount} was rejected. Earnings balance refunded.",
        payload: { withdrawal_id: resource.id }
      )
    end

    redirect_to resource_path, alert: "Withdrawal request rejected and earnings refunded to expert."
  end

  index do
    selectable_column
    id_column
    column(:account) { |req| req.account&.full_name }
    column(:upi_id)
    column("Requested (₹)") { |req| "₹#{req.amount}" }
    column("20% Cut (₹)") { |req| "₹#{req.deduction_amount}" }
    column("Net Payout (₹)") { |req| "₹#{req.net_amount}" }
    column :status
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row(:account) { |req| req.account&.full_name }
      row(:account_email) { |req| req.account&.email }
      row :upi_id
      row("Requested Amount") { |req| "₹#{req.amount}" }
      row("20% Platform Cut") { |req| "₹#{req.deduction_amount}" }
      row("Net Payout Amount") { |req| "₹#{req.net_amount}" }
      row :status
      row :failure_reason
      row :approved_at
      row :completed_at
      row :created_at
      row :updated_at
    end
  end

  filter :account_full_name, as: :string, label: "Account Name"
  filter :upi_id
  filter :status
  filter :created_at
end
