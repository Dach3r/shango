FactoryBot.define do
  factory :collection do
    project
    creator { nil }
    sequence(:name) { |n| "Collection #{n}" }
    auth_type { "none" }
  end
end
