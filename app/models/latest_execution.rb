# The last response a user got for a request that has not been saved to history: one row per user and request (or new
# draft), overwritten on every run, so the response panel survives restarts and reloads without piling up rows.
# The payload is encrypted because a response can carry secrets the masker does not know about.
class LatestExecution < ApplicationRecord
  belongs_to :project
  belongs_to :user
  belongs_to :api_request, optional: true
  belongs_to :request_draft, optional: true

  encrypts :payload

  scope :stale, ->(cutoff) { where(updated_at: ..cutoff) }

  # Keeps `execution` as the user's latest run of its request, replacing the previous one.
  def self.keep(execution)
    row = slot(execution)
    row.assign_attributes(project_id: execution.project_id, execution_id: execution.id, payload: execution.storable_attributes.to_json)
    row.save!
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def self.slot(execution)
    subject = execution.api_request.persisted? ? { api_request_id: execution.api_request_id } : { request_draft_id: execution.api_request_id }
    find_or_initialize_by(user_id: execution.user_id, **subject)
  end

  def execution
    RequestExecution.new(JSON.parse(payload).merge("api_request_id" => api_request_id || request_draft_id))
  end
end
