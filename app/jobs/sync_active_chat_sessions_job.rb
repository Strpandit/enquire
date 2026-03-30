class SyncActiveChatSessionsJob < ApplicationJob
  queue_as :default

  def perform
    ChatSession.billable.find_each do |chat_session|
      Chat::BillingService.new(chat_session).sync!
    rescue StandardError
      next
    end
  end
end
