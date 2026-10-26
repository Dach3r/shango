class RequestExecution < ApplicationRecord
  KEEP_PER_REQUEST = 50
  PENDING_TTL = 30.minutes

  belongs_to :project
  belongs_to :api_request
  belongs_to :user, optional: true
  belongs_to :environment, optional: true

  scope :recent, -> { order(created_at: :desc) }

  def self.pending(id)
    attributes = Rails.cache.read(pending_key(id))
    new(attributes) if attributes
  end

  def self.pending_key(id)
    "request_execution/pending/#{id}"
  end

  def self.latest_key(api_request_id, user_id)
    "request_execution/latest/#{api_request_id}/#{user_id}"
  end

  # The last response the user got for a request: the freshest unsaved run still cached, else the newest saved one.
  def self.latest_for(api_request, user)
    pending(Rails.cache.read(latest_key(api_request.id, user.id))) || api_request.request_executions.where(user_id: user.id).recent.first
  end

  # Keeps an unsaved execution available for a while so it can be saved later without re-sending the request.
  def stash
    Rails.cache.write(self.class.pending_key(id), attributes, expires_in: PENDING_TTL)
    Rails.cache.write(self.class.latest_key(api_request_id, user_id), id, expires_in: PENDING_TTL)
    self
  end

  def error?
    error_kind.present?
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
