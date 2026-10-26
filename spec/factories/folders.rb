FactoryBot.define do
  factory :folder do
    collection
    sequence(:name) { |n| "Folder #{n}" }
    auth_type { "inherit" }
  end
end
