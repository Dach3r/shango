FactoryBot.define do
  factory :notification_channel do
    project
    sequence(:name) { |n| "Channel #{n}" }
    kind { "webhook" }
    target { "https://hooks.example.com/shango" }

    trait :email do
      kind { "email" }
      target { "ops@example.com" }
    end

    trait :slack do
      kind { "slack" }
      target { "https://hooks.slack.com/services/T000/B000/abcd1234" }
    end

    trait :discord do
      kind { "discord" }
      target { "https://discord.com/api/webhooks/123/abcd1234" }
    end
  end

  factory :monitor_channel do
    uptime_monitor
    notification_channel { association(:notification_channel, project: uptime_monitor.project) }
  end

  factory :notification_delivery do
    notification_channel
    event { "test" }

    trait :opened do
      event { "incident_opened" }
      incident { association(:incident, uptime_monitor: association(:uptime_monitor, project: notification_channel.project)) }
    end
  end
end
