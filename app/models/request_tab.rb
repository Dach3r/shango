class RequestTab < ApplicationRecord
  belongs_to :user
  belongs_to :api_request
end
