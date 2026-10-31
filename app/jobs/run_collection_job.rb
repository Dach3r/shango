# Sends the requests of a CollectionRun outside the web thread (see ApiClient::Runs::Perform); the run page refreshes itself as items finish.
class RunCollectionJob < ApplicationJob
  queue_as :executions

  # A member's runs queue up one at a time instead of occupying every worker.
  limits_concurrency to: 1, key: ->(run_id) { CollectionRun.where(id: run_id).pick(:user_id) }, duration: 30.minutes

  def perform(run_id)
    run = CollectionRun.find_by(id: run_id)
    return unless run&.queued?

    ApiClient::Runs::Perform.call(run:)
  end
end
