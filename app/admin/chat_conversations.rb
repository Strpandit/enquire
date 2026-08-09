ActiveAdmin.register ChatConversation do
  actions :index, :show

  index do
    id_column
    column(:customer) { |conv| conv.customer_account&.full_name }
    column(:business) { |conv| conv.business_profile&.business_name }
    column :status
    column :last_message_preview
    column :last_message_at
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row(:customer) { |conv| conv.customer_account&.full_name }
      row(:business) { |conv| conv.business_profile&.business_name }
      row :status
      row :last_message_preview
      row :last_message_at
      row :created_at
      row :updated_at
    end

    panel "Chat Messages" do
      table_for chat_conversation.chat_messages.order(created_at: :asc) do
        column(:sender) { |msg| msg.sender_account&.full_name }
        column :content
        column :sent_at
      end
    end
  end

  filter :customer_account_full_name, as: :string, label: "Customer Name"
  filter :business_profile_business_name, as: :string, label: "Business Name"
  filter :status
  filter :created_at
end
