FactoryBot.define do
  factory :request_execution do
    api_request
    project { api_request.project }
    http_method { "GET" }
    url { "https://api.example.com/items" }
    status { 200 }
  end
end
