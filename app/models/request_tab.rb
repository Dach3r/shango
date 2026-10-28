class RequestTab < ApplicationRecord
  belongs_to :user
  belongs_to :api_request, optional: true
  belongs_to :request_draft, optional: true
end
