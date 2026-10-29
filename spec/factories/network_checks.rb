FactoryBot.define do
  factory :network_check do
    project
    kind { "dns" }
    target { "example.com" }
    outcome { "ok" }
    input { { "domain" => "example.com", "type" => "A", "expected" => "" } }
    result do
      {
        "host" => "example.com", "type" => "A", "expected" => nil,
        "rows" => [{ "name" => "Google", "ip" => "8.8.8.8", "group" => "public", "status" => "ok", "answers" => ["203.0.113.10"], "ttl" => 60, "ms" => 12, "match" => nil }],
        "summary" => { "total" => 1, "answered" => 1, "matched" => 0, "agree" => true }
      }
    end

    trait :ports do
      kind { "ports" }
      input { { "host" => "example.com", "ports" => "22,80" } }
      result do
        {
          "host" => "example.com", "address" => "203.0.113.9",
          "rows" => [{ "port" => 22, "service" => "ssh", "status" => "open", "ms" => 7 }, { "port" => 80, "service" => "http", "status" => "closed", "ms" => 6 }],
          "counts" => { "open" => 1, "closed" => 1, "filtered" => 0 }
        }
      end
    end

    trait :subnet do
      kind { "subnet" }
      target { "192.168.1.0/24" }
      input { { "network" => "192.168.1.10/24", "contains" => "192.168.1.77" } }
      result { Network::Checks::Codec.dump("subnet", Network::Subnets::Calculate.call(network: "192.168.1.10/24", contains: "192.168.1.77").data) }
    end

    trait :ping do
      kind { "ping" }
      input { { "host" => "example.com", "port" => "443", "attempts" => "2" } }
      result do
        {
          "host" => "example.com", "address" => "203.0.113.9", "port" => 443,
          "attempts" => [{ "status" => "open", "ms" => 12 }, { "status" => "filtered", "ms" => 2000 }],
          "summary" => { "sent" => 2, "received" => 1, "loss" => 50, "min" => 12, "max" => 12, "avg" => 12, "open" => 1, "stopped" => false }
        }
      end
    end
  end
end
