class SyncActiveChatSessionsJob < ApplicationJob
  queue_as :default

  def perform
    ChatSession.billable.find_each do |chat_session|
      Chat::BillingService.new(chat_session).sync!
    rescue StandardError => e
      Rails.logger.error("[SyncActiveChatSessionsJob] chat_session=#{chat_session.id} failed: #{e.class}: #{e.message}")
      next
    end
  end
end
