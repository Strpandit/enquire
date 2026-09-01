module Api
  module V1
    class CallHistoriesController < BaseController
      def index
        call_histories = CallHistory
          .for_account(current_account.id)
          .includes(caller_account: { profile_pic_attachment: :blob }, receiver_account: { profile_pic_attachment: :blob })
          .recent
          .page(params[:page])
          .per(per_page)

        render json: {
          call_histories: CallHistoryBlueprint.render_as_hash(call_histories, view: :list),
          pagination: pagination_meta(call_histories)
        }, status: :ok
      end

      def create
        receiver_id = params.require(:receiver_account_id)
        call_type = params.require(:call_type)
        channel_name = params.require(:channel_name)

        receiver = Account.find_by(id: receiver_id) || BusinessProfile.find_by(id: receiver_id)&.account
        raise ActionController::ParameterMissing, "Receiver account not found" unless receiver

        history = Calls::HistoryService.initiate_call(
          caller: current_account,
          receiver: receiver,
          call_type: call_type,
          channel_name: channel_name
        )

        render json: {
          call_history: CallHistoryBlueprint.render_as_hash(history)
        }, status: :created
      rescue => error
        render_service_error(error)
      end

      def accept
        history = find_participant_call
        history = Calls::HistoryService.accept_call!(history: history, account: current_account)

        render json: {
          message: "Call accepted",
          call_history: CallHistoryBlueprint.render_as_hash(history)
        }, status: :ok
      rescue => error
        render_service_error(error)
      end

      def decline
        history = find_participant_call
        history = Calls::HistoryService.decline_call!(history: history, account: current_account)

        render json: {
          message: "Call declined",
          call_history: CallHistoryBlueprint.render_as_hash(history)
        }, status: :ok
      rescue => error
        render_service_error(error)
      end

      def heartbeat
        history = find_participant_call
        duration = params.fetch(:duration_seconds, 0).to_i
        history = Calls::HistoryService.sync_call_billing!(history: history, duration_seconds: duration)

        render json: {
          message: "Call billing synced",
          call_history: CallHistoryBlueprint.render_as_hash(history)
        }, status: :ok
      rescue => error
        render_service_error(error)
      end

      def end_call
        history = find_participant_call
        duration = params.fetch(:duration_seconds, 0).to_i
        end_reason = params.fetch(:end_reason, "ended by user")

        Calls::HistoryService.finish_call!(
          history: history,
          duration_seconds: duration,
          end_reason: end_reason
        )

        render json: { message: "Call ended successfully" }, status: :ok
      rescue => error
        render_service_error(error)
      end

      private

      def find_participant_call
        history = CallHistory.find(params[:id])
        raise ActionController::ParameterMissing, "Call history not found" unless history
        raise ActionController::ParameterMissing, "You are not a participant in this call" unless [ history.caller_account_id, history.receiver_account_id ].include?(current_account.id)
        history
      end
    end
  end
end
