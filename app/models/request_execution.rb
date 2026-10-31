class RequestExecution < ApplicationRecord
  KEEP_PER_REQUEST = 50
  STORED_BODY_BYTES = 256.kilobytes

  belongs_to :project
  belongs_to :api_request
  belongs_to :user, optional: true
  belongs_to :environment, optional: true

  scope :recent, -> { order(created_at: :desc) }

  # The unsaved run with this id, if it is still the user's latest one for its request.
  def self.pending(id)
    LatestExecution.find_by(execution_id: id)&.execution
  end

  # The user's unsaved latest run of a request, which lives only while its tab is open.
  def self.unsaved_for(api_request, user)
    key = api_request.persisted? ? { api_request_id: api_request.id } : { request_draft_id: api_request.id }
    LatestExecution.find_by(user_id: user.id, **key)&.execution
  end

  # The last response the user got for a request: the unsaved latest run, else the newest saved one.
  def self.latest_for(api_request, user)
    unsaved_for(api_request, user) || api_request.request_executions.where(user_id: user.id).recent.first
  end

  # Keeps an unsaved execution as the latest one of its request until it is saved to history or replaced by the next run.
  def stash
    LatestExecution.keep(self)
    self
  end

  # What survives in the latest run and history: bodies are cut to STORED_BODY_BYTES (the panel shows the full response
  # once, straight from the run) so a few large responses cannot fill the database.
  def storable_attributes
    stored = attributes.dup
    %w[response_body request_body].each do |name|
      value = stored[name]
      next unless value.is_a?(String) && value.bytesize > STORED_BODY_BYTES

      stored[name] = value.byteslice(0, STORED_BODY_BYTES).scrub("")
      stored["body_truncated"] = true if name == "response_body"
    end
    stored
  end

  def error?
    error_kind.present?
  end

  def failed_tests
    test_results.count { |outcome| outcome["status"] == "failed" }
  end

  def passed_tests
    test_results.count { |outcome| outcome["status"] == "passed" }
  end

  def status_class
    return :error if error?

    case status
    when 100..399 then :success
    when 400..499 then :client_error
    else :server_error
    end
  end
end
