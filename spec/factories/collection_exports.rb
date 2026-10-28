FactoryBot.define do
  factory :collection_export do
    project
    user
    collection { association :collection, project: }
    export_format { "shango" }
    expires_at { 1.hour.from_now }

    trait :done do
      status { "done" }
      progress { 100 }
      filename { "pets.shango.json" }
      content_type { "application/json" }
      content { Base64.strict_encode64('{"ok":true}') }
    end
  end
end
