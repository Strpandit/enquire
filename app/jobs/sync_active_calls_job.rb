class SyncActiveCallsJob < ApplicationJob
  queue_as :default

  STALE_AFTER = 90.seconds

  def perform
    CallHistory.where(status: :active).find_each do |history|
      elapsed = history.started_at ? (Time.current - history.started_at).to_i : 0
      Calls::HistoryService.sync_call_billing!(history: history)

      history.reload
      if history.active? && history.updated_at < STALE_AFTER.ago
        Calls::HistoryService.finish_call!(history: history, duration_seconds: elapsed, end_reason: "stale_no_heartbeat")
      end
    rescue StandardError => e
      Rails.logger.error("[SyncActiveCallsJob] call_history=#{history.id} failed: #{e.class}: #{e.message}")
      next
    end
  end
end
