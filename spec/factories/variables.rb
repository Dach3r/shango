FactoryBot.define do
  factory :variable do
    environment
    sequence(:key) { |n| "VAR_#{n}" }
    value { "value" }

    trait :secret do
      secret { true }
    end
  end
end
