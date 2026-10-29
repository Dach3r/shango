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
