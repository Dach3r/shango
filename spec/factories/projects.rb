FactoryBot.define do
  factory :project do
    sequence(:name) { |n| "Project #{n}" }
    icon { "rocket" }

    trait :archived do
      archived_at { Time.current }
    end
  end
end
