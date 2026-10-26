FactoryBot.define do
  factory :membership do
    user
    project
    role { "member" }

    trait :owner do
      role { "owner" }
    end

    trait :revoked do
      revoked_at { Time.current }
    end
  end
end
