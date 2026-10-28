FactoryBot.define do
  factory :environment do
    project
    creator { nil }
    sequence(:name) { |n| "Environment #{n}" }
  end
end
