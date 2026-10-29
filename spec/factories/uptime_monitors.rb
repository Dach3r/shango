FactoryBot.define do
  factory :uptime_monitor do
    project
    sequence(:name) { |n| "Monitor #{n}" }
    kind { "http" }
    interval { 300 }
    settings { { "mode" => "url", "url" => "https://example.com/health" } }

    trait :request do
      api_request { association(:api_request, strategy: :create, collection: association(:collection, strategy: :create, project:)) }
      settings { { "mode" => "request" } }
    end

    trait :tcp do
      kind { "tcp" }
      settings { { "host" => "example.com", "port" => 5432 } }
    end

    trait :ssl do
      kind { "ssl" }
      settings { { "host" => "example.com" } }
    end

    trait :domain do
      kind { "domain" }
      interval { 86_400 }
      settings { { "host" => "example.com" } }
    end

    trait :push do
      kind { "push" }
      interval { 3600 }
      settings { {} }
      push_token_digest { UptimeMonitor.digest(SecureRandom.hex) }
    end
  end

  factory :check_result do
    uptime_monitor
    status { "up" }
    response_ms { 120 }
    http_status { 200 }
    checked_at { Time.current }
  end

  factory :check_rollup do
    uptime_monitor
    hour { Time.current.beginning_of_hour }
    checks { 12 }
    failures { 0 }
    response_ms_sum { 1440 }
    response_ms_max { 300 }
  end

  factory :incident do
    uptime_monitor
    project { uptime_monitor.project }
    cause { "connection_timeout" }
    started_at { 10.minutes.ago }
  end
end
