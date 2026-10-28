FactoryBot.define do
  factory :request_draft do
    project
    user
    name { "New request" }
    payload { "{}" }

    trait :for_request do
      api_request { association :api_request, project: }
      name { api_request.name }
    end
  end
end
