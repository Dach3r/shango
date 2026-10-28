FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    first_name { "Ada" }
    last_name { "Lovelace" }
    password { "password" }
    password_confirmation { "password" }

    trait :confirmed do
      confirmed_at { Time.current }
    end
  end
end
