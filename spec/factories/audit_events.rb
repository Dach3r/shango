FactoryBot.define do
  factory :audit_event do
    project
    actor { association :user }
    kind { "member_revoked" }
  end
end
