# Sends an API Client request outside the web thread. The outcome is stashed as a pending RequestExecution and the
# run state flips to done; the browser polls Workbench::Requests::Executions::ResultsController for it.
class RunRequestJob < ApplicationJob
  queue_as :executions

  # A user's runs queue up behind two running ones instead of occupying every worker.
  limits_concurrency to: 2, key: ->(user_id, *) { user_id }, duration: 3.minutes

  def perform(user_id, api_request_id, environment_id, run_id)
    state = ApiClient::Executions::RunState
    return state.finish(run_id, "cancelled") if state.cancelled?(run_id)

    api_request = ApiRequest.find(api_request_id)
    execution = ApiClient::Requests::Dispatch.call(
      api_request:, environment: Environment.find_by(id: environment_id), user: User.find(user_id), id: run_id, cancelled: -> { state.cancelled?(run_id) }
    ).record
    state.finish(run_id, execution.error_kind == "cancelled" ? "cancelled" : "done")
  rescue StandardError => error
    Rails.logger.error("RunRequestJob #{run_id} failed: #{error.class}: #{error.message}")
    state.finish(run_id, "failed")
  end
end
