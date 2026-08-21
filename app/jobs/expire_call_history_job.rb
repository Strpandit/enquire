class ExpireCallHistoryJob < ApplicationJob
  queue_as :default

  def perform(call_history_id)
    history = CallHistory.find_by(id: call_history_id)
    return if history.blank? || !history.initiated?
    return if history.created_at > CallHistory::REQUEST_TIMEOUT.ago

    ActiveRecord::Base.transaction do
      history.update!(status: :missed, ended_at: Time.current, end_reason: "no_answer")

      Notifications::Creator.call(
        recipient: history.receiver_account,
        actor: history.caller_account,
        notifiable: history,
        notification_type: "missed_call",
        title: "Missed #{history.voice? ? 'Voice' : 'Video'} Call",
        body: "You missed a #{history.voice? ? 'voice' : 'video'} call from #{history.caller_account.full_name}.",
        payload: {
          call_history_id: history.id,
          call_type: history.call_type,
          channel_name: history.channel_name,
          event: "missed_call"
        }
      )

      # Also notify the caller that their call was not answered
      Notifications::Creator.call(
        recipient: history.caller_account,
        actor: history.receiver_account,
        notifiable: history,
        notification_type: "call_not_answered",
        title: "Call Not Answered",
        body: "#{history.receiver_account.full_name} did not answer your #{history.voice? ? 'voice' : 'video'} call.",
        payload: {
          call_history_id: history.id,
          call_type: history.call_type,
          event: "call_not_answered"
        }
      )

      Notifications::Broadcaster.broadcast_payload(
        history.receiver_account_id,
        {
          type: "call_history",
          event: "call_missed",
          call_history_id: history.id,
          channel_name: history.channel_name
        }
      )

      Notifications::Broadcaster.broadcast_payload(
        history.caller_account_id,
        {
          type: "call_history",
          event: "call_unanswered",
          call_history_id: history.id,
          channel_name: history.channel_name
        }
      )
    end
  end
end
