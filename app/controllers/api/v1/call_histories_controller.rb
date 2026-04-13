module Api
  module V1
    class CallHistoriesController < BaseController
      def index
        call_histories = current_account.call_histories_as_caller
          .or(CallHistory.where(receiver_account_id: current_account.id))
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

        receiver = Account.find(receiver_id)
        raise ActionController::ParameterMissing, "Invalid receiver account" unless receiver

        business_profile = receiver.business_profile
        raise ActionController::ParameterMissing, "Receiver does not have a business profile" unless business_profile

        history = Calls::HistoryService.start_call(
          caller: current_account,
          receiver: receiver,
          call_type: call_type,
          channel_name: channel_name
        )

        render json: {
          call_history: CallHistoryBlueprint.render_as_hash(history)
        }, status: :created
      rescue StandardError => error
        render json: { errors: [error.message] }, status: :unprocessable_entity
      end

      def end_call
        history = CallHistory.find(params[:id])
        raise ActionController::ParameterMissing, "Call history not found" unless history
        raise ActionController::ParameterMissing, "You are not a participant in this call" unless [history.caller_account_id, history.receiver_account_id].include?(current_account.id)

        duration = params.fetch(:duration_seconds, 0).to_i
        end_reason = params.fetch(:end_reason, "ended by user")

        Calls::HistoryService.create_history(
          caller: history.caller_account,
          receiver: history.receiver_account,
          call_type: history.call_type,
          channel_name: history.channel_name,
          business_profile: history.receiver_account.business_profile,
          duration_seconds: duration,
          end_reason: end_reason
        )

        render json: { message: "Call ended successfully" }, status: :ok
      rescue StandardError => error
        render json: { errors: [error.message] }, status: :unprocessable_entity
      end
    end
  end
end
