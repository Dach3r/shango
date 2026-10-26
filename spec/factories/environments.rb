FactoryBot.define do
  factory :environment do
    project
    sequence(:name) { |n| "Environment #{n}" }
  end
end
