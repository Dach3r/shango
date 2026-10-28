# Unsaved editor state of a request, per user. Without an `api_request` it is a request that does not exist yet
# (nothing is written to `api_requests` until the user saves it); with one it holds pending edits of a saved request.
# The payload is encrypted because headers and body may carry credentials.
class RequestDraft < ApplicationRecord
  MAX_BYTES = 1.megabyte

  belongs_to :project
  belongs_to :user
  belongs_to :api_request, optional: true

  has_many :request_tabs, dependent: :delete_all
  has_many :latest_executions, dependent: :delete_all

  encrypts :payload

  validates :name, presence: true
  validates :http_method, inclusion: { in: ApiRequest::METHODS }
  validate :payload_within_limit

  scope :stale, ->(cutoff) { where(updated_at: ..cutoff) }

  def data
    JSON.parse(payload)
  rescue JSON::ParserError
    {}
  end

  def data=(attributes)
    self.payload = attributes.to_json
  end

  def new_request?
    api_request_id.nil?
  end

  # Never edited since it was opened, so closing its tab needs no confirmation.
  def untouched?
    updated_at == created_at
  end

  private

  def payload_within_limit
    errors.add(:payload, :too_long, count: MAX_BYTES) if payload.to_s.bytesize > MAX_BYTES
  end
end
