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

  # Keeps an unsaved execution available for a while so it can be saved later without re-sending the request.
  def stash
    Rails.cache.write(self.class.pending_key(id), attributes, expires_in: PENDING_TTL)
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
