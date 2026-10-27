FactoryBot.define do
  factory :cookie do
    project
    environment { nil }
    domain { "api.example.com" }
    path { "/" }
    sequence(:name) { |n| "cookie_#{n}" }
    value { "abc123" }
  end
end
