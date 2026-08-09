ActiveAdmin.register WalletTransaction do
  actions :index, :show

  index do
    id_column
    column(:account) { |tx| tx.account&.full_name }
    column :entry_type
    column("Amount") { |tx| "₹#{tx.amount_cents / 100.0}" }
    column("Balance After") { |tx| "₹#{tx.balance_after_cents / 100.0}" }
    column :description
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row(:account) { |tx| tx.account&.full_name }
      row :entry_type
      row("Amount") { |tx| "₹#{tx.amount_cents / 100.0}" }
      row("Balance After Transaction") { |tx| "₹#{tx.balance_after_cents / 100.0}" }
      row :description
      row :reference_type
      row :reference_id
      row :created_at
    end
  end

  filter :entry_type
  filter :account_full_name, as: :string, label: "Account Name"
  filter :description
  filter :created_at
end
