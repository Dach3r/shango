FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    first_name { "Ada" }
    last_name { "Lovelace" }
    password { "password123" }
    password_confirmation { "password123" }
  end
end
