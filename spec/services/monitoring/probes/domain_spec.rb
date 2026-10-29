require "rails_helper"

RSpec.describe Monitoring::Probes::Domain do
  let(:now) { Time.zone.parse("2026-10-29 12:00:00") }
  let(:monitor) { build(:uptime_monitor, :domain, timeout: 8, settings: { "host" => "www.example.com", "days_before" => 30 }) }

  def lookup(expires: "2027-06-01T00:00:00Z", statuses: ["active"])
    Result.success(nil, domain: { expires:, statuses: })
  end

  def probe(result = lookup)
    allow(Network::Lookups::Domain).to receive(:call).and_return(result)
    described_class.call(monitor, now:)
  end

  it "is up with a registration far from its expiry, which it keeps", :aggregate_failures do
    outcome = probe

    expect(outcome).to have_attributes(status: "up", expires_at: Time.utc(2027, 6, 1))
    expect(outcome.response_ms).to be_a(Integer)
    expect(Network::Lookups::Domain).to have_received(:call).with(host: "www.example.com", deadline: kind_of(Float))
  end

  it "is down when expiring, expired, on hold, pending delete or not registered", :aggregate_failures do
    expect(probe(lookup(expires: "2026-11-15T00:00:00Z"))).to have_attributes(status: "down", error: "domain_expiring", detail: "2026-11-15", expires_at: Time.utc(2026, 11, 15))
    expect(probe(lookup(expires: "2026-10-01T00:00:00Z"))).to have_attributes(error: "domain_expired", detail: "2026-10-01")
    expect(probe(lookup(statuses: ["client hold"]))).to have_attributes(error: "domain_on_hold")
    expect(probe(lookup(statuses: ["pending delete"]))).to have_attributes(error: "domain_pending_delete")
    expect(probe(lookup(expires: nil, statuses: ["server hold"]))).to have_attributes(error: "domain_on_hold", detail: nil, expires_at: nil)
    expect(probe(Result.failure(error: :not_registered))).to have_attributes(status: "down", error: "domain_not_registered")
  end

  it "is unknown, never down, when the registry cannot tell", :aggregate_failures do
    expect(probe(Result.failure(error: :no_rdap_service))).to have_attributes(status: "unknown", error: "no_rdap_service")
    expect(probe(Result.failure(error: :rdap_unavailable))).to have_attributes(status: "unknown", error: "rdap_unavailable")
    expect(probe(Result.failure(error: :unavailable))).to have_attributes(status: "unknown", error: "rdap_unavailable")
    expect(probe(Result.failure(error: :something_else))).to have_attributes(status: "unknown", error: "rdap_unavailable")
    expect(probe(lookup(expires: nil))).to have_attributes(status: "unknown", error: "no_expiry")
  end

  it "refuses an IP address and passes on why the host is not usable", :aggregate_failures do
    monitor.settings = { "host" => "203.0.113.9", "days_before" => 30 }
    expect(described_class.call(monitor)).to have_attributes(status: "down", error: "invalid_host")
    monitor.settings = { "host" => "{{missing}}", "days_before" => 30 }
    expect(described_class.call(monitor)).to have_attributes(error: "unresolved_variable")
  end
end
