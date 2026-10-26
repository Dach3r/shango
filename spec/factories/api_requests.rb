FactoryBot.define do
  factory :api_request do
    collection
    sequence(:name) { |n| "Request #{n}" }
    http_method { "GET" }
    url { "https://api.example.com/items" }
  end
end
