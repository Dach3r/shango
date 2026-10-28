FactoryBot.define do
  factory :latest_execution do
    project
    user
    api_request { association :api_request, project: }
    execution_id { SecureRandom.uuid }
    payload { "{}" }
  end
end
