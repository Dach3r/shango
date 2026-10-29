require "rails_helper"

RSpec.describe Network::Checks::Digest do
  def dns(summary, expected: nil)
    described_class.for(:dns, { host: "a.com", type: "A", expected:, summary: })
  end

  it "settles a DNS run when every resolver matches the expected value", :aggregate_failures do
    digest = dns({ total: 4, answered: 4, matched: 4, agree: true }, expected: "203.0.113.10")

    expect(digest).to have_attributes(label: "a.com · A", tone: "ok", progress: 100, key: "network.dns.summary.expected")
    expect(digest.args).to eq(matched: 4, answered: 4, total: 4)
  end

  it "warns while a change is still spreading", :aggregate_failures do
    digest = dns({ total: 4, answered: 4, matched: 3, agree: false }, expected: "203.0.113.10")

    expect(digest).to have_attributes(tone: "warn", progress: 75)
  end

  it "fails when nobody matches or answers", :aggregate_failures do
    expect(dns({ total: 4, answered: 4, matched: 0, agree: false }, expected: "x")).to have_attributes(tone: "bad", progress: 0)
    expect(dns({ total: 4, answered: 0, matched: 0, agree: true })).to have_attributes(tone: "bad", key: "network.dns.summary.answered")
  end

  it "settles a run without expected value once every resolver answered, even if the answers differ", :aggregate_failures do
    expect(dns({ total: 2, answered: 2, matched: 0, agree: true }).tone).to eq("ok")
    expect(dns({ total: 2, answered: 2, matched: 0, agree: false }).tone).to eq("ok")
    expect(dns({ total: 2, answered: 1, matched: 0, agree: true }).tone).to eq("warn")
  end

  it "handles an empty run" do
    expect(dns({ total: 0, answered: 0, matched: 0, agree: true }).progress).to eq(0)
  end

  it "summarizes a port check", :aggregate_failures do
    ports = ->(open) { described_class.for(:ports, { host: "a.com", counts: { open:, closed: 1, filtered: 0 } }) }

    expect(ports.call(2)).to have_attributes(label: "a.com", tone: "ok", key: "network.ports.summary", progress: nil)
    expect(ports.call(0).tone).to eq("warn")
  end

  it "summarizes a TCP ping", :aggregate_failures do
    ping = ->(received) { described_class.for(:ping, { host: "a.com", port: 443, summary: { sent: 3, received:, loss: 0 } }) }

    expect(ping.call(3)).to have_attributes(label: "a.com:443", tone: "ok", key: "network.ping.summary")
    expect(ping.call(1).tone).to eq("warn")
    expect(ping.call(0).tone).to eq("bad")
  end

  it "labels a subnet with its network and usable hosts", :aggregate_failures do
    digest = described_class.for(:subnet, Network::Subnets::Calculate.call(network: "10.0.0.0/16").data)

    expect(digest).to have_attributes(label: "10.0.0.0/16", tone: "ok", key: "network.subnet.summary", progress: nil)
    expect(digest.args).to eq(hosts: "65,534", version: 4)
    expect(described_class.for(:subnet, Network::Subnets::Calculate.call(network: "2001:db8::/48").data).args[:hosts]).to eq("2^80")
  end

  it "warns when the address looked for is outside the subnet", :aggregate_failures do
    inside = Network::Subnets::Calculate.call(network: "10.0.0.0/16", contains: "10.0.9.9").data
    outside = Network::Subnets::Calculate.call(network: "10.0.0.0/16", contains: "10.1.0.1").data

    expect(described_class.for(:subnet, inside).tone).to eq("ok")
    expect(described_class.for(:subnet, outside).tone).to eq("warn")
  end

  describe "TLS" do
    def tls(validity: "valid", tones: [])
      data = build(:network_check, :tls).result.deep_symbolize_keys
      data[:certificate][:validity] = validity
      described_class.for(:tls, data.merge(findings: tones.map { |tone| { key: "expired", tone:, args: {} } }))
    end

    it "labels a TLS check with host and port and its expiry", :aggregate_failures do
      digest = tls

      expect(digest).to have_attributes(label: "example.com:443", tone: "ok", key: "network.tls.summary.valid", progress: nil)
      expect(digest.args).to eq(date: "2026-11-30", version: "TLSv1.3")
    end

    it "takes the tone of the worst finding", :aggregate_failures do
      expect(tls(tones: %w[warn]).tone).to eq("warn")
      expect(tls(tones: %w[warn bad]).tone).to eq("bad")
    end

    it "words the summary after the validity", :aggregate_failures do
      expect(tls(validity: "expiring").key).to eq("network.tls.summary.valid")
      expect(tls(validity: "expired").key).to eq("network.tls.summary.expired")
      expect(tls(validity: "not_yet_valid")).to have_attributes(key: "network.tls.summary.not_yet_valid", args: include(date: "2026-09-01"))
    end
  end

  it "has a digest for every kind and none for unknown ones", :aggregate_failures do
    expect(described_class::KINDS.keys).to match_array(NetworkCheck.kinds.keys)
    expect { described_class.for("nmap", {}) }.to raise_error(KeyError)
  end
end
