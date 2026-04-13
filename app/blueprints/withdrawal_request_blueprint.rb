class WithdrawalRequestBlueprint < Blueprinter::Base
  fields :id, :amount_cents, :upi_id, :status, :approved_at, :completed_at, :failure_reason, :created_at, :updated_at
end
