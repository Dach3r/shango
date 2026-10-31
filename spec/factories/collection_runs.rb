FactoryBot.define do
  factory :collection_run do
    project
    collection { association :collection, project: }
    user
    options { { "stop_on_failure" => false, "persist_variables" => false, "delay_ms" => 0 } }

    # The state machine owns `status`, so traits move the column without going through the events.
    trait :running do
      started_at { 1.minute.ago }

      after(:create) { |run| run.update_columns(status: "running") }
    end

    trait :completed do
      started_at { 2.minutes.ago }
      finished_at { 1.minute.ago }

      after(:create) { |run| run.update_columns(status: "completed") }
    end
  end

  factory :collection_run_item do
    collection_run
    api_request { association :api_request, collection: collection_run.collection }
    request_name { api_request&.name || "Request" }
    http_method { "GET" }
    sequence(:position)
  end
end
