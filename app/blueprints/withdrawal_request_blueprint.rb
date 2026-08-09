class WithdrawalRequestBlueprint < Blueprinter::Base
  identifier :id

  fields :amount_cents, :upi_id, :status, :approved_at, :completed_at, :failure_reason, :created_at, :updated_at

  field :amount do |req|
    req.amount
  end

  field :deduction_amount do |req|
    req.deduction_amount
  end

  field :net_amount do |req|
    req.net_amount
  end
end
