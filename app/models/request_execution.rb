class RequestExecution < ApplicationRecord
  KEEP_PER_REQUEST = 50

  belongs_to :project
  belongs_to :api_request
  belongs_to :user, optional: true
  belongs_to :environment, optional: true

  scope :recent, -> { order(created_at: :desc) }

  def error?
    error_kind.present?
  end

  # 2xx and 3xx are shown as success, everything else as a failure.
  def status_class
    return :error if error?

    case status
    when 100..399 then :success
    when 400..499 then :client_error
    else :server_error
    end
  end
end
