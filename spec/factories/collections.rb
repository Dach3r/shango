FactoryBot.define do
  factory :collection do
    project
    sequence(:name) { |n| "Collection #{n}" }
    auth_type { "none" }
  end
end
