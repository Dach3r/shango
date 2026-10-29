require "rails_helper"

RSpec.describe Network::TlsChecks::Findings do
  let(:certificate) { { not_before: "2026-01-01T00:00:00Z", not_after: "2026-04-01T00:00:00Z", key: { type: "RSA", bits: 2048 }, signature: "sha256WithRSAEncryption" } }
  let(:trusted) { { status: "trusted", reason: nil, code: nil } }

  def findings(validity: "valid", trust: trusted, host_match: true, version: "TLSv1.3", **changes)
    described_class.call(certificate: certificate.merge(changes), validity:, trust:, host_match:, host: "example.com", session: { version: })
  end

  it "finds nothing wrong with a good certificate" do
    expect(findings).to be_empty
  end

  it "reports the dates", :aggregate_failures do
    expect(findings(validity: "expired")).to eq([{ key: "expired", tone: "bad", args: { date: "2026-04-01" } }])
    expect(findings(validity: "not_yet_valid")).to eq([{ key: "not_yet_valid", tone: "bad", args: { date: "2026-01-01" } }])
    expect(findings(validity: "expiring")).to eq([{ key: "expiring", tone: "warn", args: { date: "2026-04-01" } }])
  end

  it "reports a host name the certificate does not cover" do
    expect(findings(host_match: false)).to eq([{ key: "name_mismatch", tone: "bad", args: { host: "example.com" } }])
  end

  it "reports why the chain is not trusted, with the code when it has no name of its own", :aggregate_failures do
    expect(findings(trust: { status: "untrusted", reason: "self_signed", code: 18 })).to eq([{ key: "untrusted.self_signed", tone: "bad", args: {} }])
    expect(findings(trust: { status: "untrusted", reason: "other", code: 26 })).to eq([{ key: "untrusted.other", tone: "bad", args: { code: "26" } }])
  end

  it "warns about old protocols, weak keys and weak signatures", :aggregate_failures do
    expect(findings(version: "TLSv1.1")).to eq([{ key: "old_protocol", tone: "warn", args: { version: "TLSv1.1" } }])
    expect(findings(key: { type: "RSA", bits: 1024 })).to eq([{ key: "weak_key", tone: "warn", args: { type: "RSA", bits: "1024" } }])
    expect(findings(key: { type: "EC", bits: 192 }).first[:key]).to eq("weak_key")
    expect(findings(key: { type: "ED25519", bits: nil })).to be_empty
    expect(findings(signature: "sha1WithRSAEncryption")).to eq([{ key: "weak_signature", tone: "warn", args: { algorithm: "sha1WithRSAEncryption" } }])
  end

  it "lists what breaks clients first" do
    expect(findings(version: "TLSv1", validity: "expiring", host_match: false).pluck(:key)).to eq(%w[name_mismatch expiring old_protocol])
  end

  it "has a text for every finding in each locale", :aggregate_failures do
    keys = %w[expired not_yet_valid expiring name_mismatch old_protocol weak_key weak_signature] + Network::Tls::Trust::REASONS.values.uniq.map { |reason| "untrusted.#{reason}" } + ["untrusted.other"]
    I18n.available_locales.each do |locale|
      keys.each { |key| expect(I18n.exists?("network.tls.findings.#{key}", locale)).to be(true), "#{locale} #{key}" }
    end
  end
end
