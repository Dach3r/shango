require "rails_helper"

RSpec.describe Monitoring::Probes::Ssl do
  let(:root) { tls_root }
  let(:now) { Time.current }
  let(:monitor) { build(:uptime_monitor, :ssl, timeout: 6, settings: { "host" => "example.com", "port" => 443, "days_before" => 14 }) }

  def session(*chain)
    Network::Tls::Handshake::Session.new(version: "TLSv1.3", cipher: "TLS_AES_256_GCM_SHA384", bits: 256, alpn: "h2", chain:)
  end

  def leaf(**)
    tls_certificate(issuer: root, **)
  end

  def probe(*chain)
    allow(Network::Tls::Handshake).to receive(:call).and_return(session(*chain))
    described_class.call(monitor, now:)
  end

  before do
    allow(Network::Destination).to receive(:call).and_return(Result.success("203.0.113.9"))
    allow(Network::Tls::Trust).to receive(:default_store).and_return(tls_store(root))
  end

  it "is up with a trusted certificate for the host and keeps its expiry", :aggregate_failures do
    cert = leaf
    outcome = probe(cert, root)

    expect(outcome).to have_attributes(status: "up", expires_at: cert.not_after.utc)
    expect(outcome.response_ms).to be_a(Integer)
    expect(Network::Tls::Handshake).to have_received(:call).with(ip: "203.0.113.9", port: 443, sni: "example.com", protocol: "tls", timeout: 6)
  end

  it "sends no SNI to an IP address" do
    monitor.settings = { "host" => "203.0.113.9", "port" => 443, "days_before" => 14 }
    probe(leaf(names: %w[203.0.113.9]), root)

    expect(Network::Tls::Handshake).to have_received(:call).with(hash_including(sni: nil))
  end

  it "is down for each problem of the certificate", :aggregate_failures do
    expect(probe).to have_attributes(status: "down", error: "no_certificate", expires_at: nil)
    expect(probe(tls_certificate)).to have_attributes(error: "untrusted_certificate", detail: "self_signed")
    expect(probe(leaf(subject: "/CN=other.example", names: %w[other.example]), root)).to have_attributes(error: "hostname_mismatch", detail: "other.example")
    expect(probe(leaf(not_before: 1.day.from_now), root)).to have_attributes(error: "certificate_not_yet_valid")
    expired = leaf(not_before: 90.days.ago, not_after: 1.day.ago)
    expect(probe(expired, root)).to have_attributes(error: "certificate_expired", detail: expired.not_after.utc.iso8601, expires_at: expired.not_after.utc)
    soon = leaf(not_after: 10.days.from_now)
    expect(probe(soon, root)).to have_attributes(error: "certificate_expiring", detail: soon.not_after.utc.to_date.iso8601)
  end

  it "maps handshake failures", :aggregate_failures do
    { Network::Tls::Handshake::Refused => "connection_refused", Network::Tls::Handshake::TimedOut => "connection_timeout" }.each do |error, cause|
      allow(Network::Tls::Handshake).to receive(:call).and_raise(error)
      expect(described_class.call(monitor)).to have_attributes(status: "down", error: cause)
    end
    allow(Network::Tls::Handshake).to receive(:call).and_raise(Network::Tls::Handshake::Failed, "wrong version number")
    expect(described_class.call(monitor)).to have_attributes(error: "tls_failed", detail: "wrong version number")
  end

  it "passes on why the host was refused" do
    allow(Network::Destination).to receive(:call).and_return(Result.failure(error: :blocked))

    expect(described_class.call(monitor)).to have_attributes(error: "blocked")
  end
end
