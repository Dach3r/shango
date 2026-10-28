FactoryBot.define do
  factory :invitation do
    project
    inviter { association :user }
    sequence(:email) { |n| "invitee#{n}@example.com" }
    role { "member" }

    trait :accepted do
      accepted_at { Time.current }
    end

    trait :revoked do
      revoked_at { Time.current }
    end

    trait :expired do
      expires_at { 1.minute.ago }
    end
  end
end
