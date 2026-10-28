require "rails_helper"

RSpec.describe Network::Checks::Codec do
  def round_trip(kind, data)
    described_class.load(kind, JSON.parse(described_class.dump(kind, data).to_json))
  end

  it "round-trips a DNS run", :aggregate_failures do
    row = Network::Dns::Row.new(name: "Google", ip: "8.8.8.8", group: :public, status: :ok, answers: ["203.0.113.10"], ttl: 60, ms: 12, match: :match)
    data = { host: "example.com", type: "A", expected: "203.0.113.10", rows: [row], summary: { total: 1, answered: 1, matched: 1, agree: true } }

    expect(round_trip("dns", data)).to eq(data)
  end

  it "keeps rows without a match" do
    row = Network::Dns::Row.new(name: "ns1", ip: nil, group: :authoritative, status: :unresolved, answers: [], ttl: nil, ms: nil, match: nil)

    expect(round_trip("dns", { host: "a.com", type: "A", expected: nil, rows: [row], summary: {} })[:rows]).to eq([row])
  end

  it "cuts long and numerous answers", :aggregate_failures do
    row = Network::Dns::Row.new(name: "Google", ip: "8.8.8.8", group: :public, status: :ok, answers: Array.new(15) { "x" * 400 }, ttl: 60, ms: 12, match: nil)
    stored = described_class.dump("dns", { host: "a.com", type: "TXT", expected: nil, rows: [row], summary: {} })["rows"]

    expect(stored.first["answers"].size).to eq(described_class::MAX_ANSWERS)
    expect(stored.first["answers"].first.length).to eq(described_class::MAX_ANSWER_LENGTH)
  end

  it "round-trips a port check" do
    data = { host: "a.com", address: "203.0.113.9", rows: [Network::PortChecks::Row.new(port: 22, service: "ssh", status: :open, ms: 7)], counts: { open: 1, closed: 0, filtered: 0 } }

    expect(round_trip("ports", data)).to eq(data)
  end

  it "round-trips a TCP ping" do
    data = { host: "a.com", address: "203.0.113.9", port: 443, attempts: [Network::Tcp::Probe::Attempt.new(status: :open, ms: 12)], summary: { sent: 1, received: 1, loss: 0, min: 12, max: 12, avg: 12, open: 1, stopped: false } }

    expect(round_trip("ping", data)).to eq(data)
  end

  it "has a codec for every kind and none for unknown ones", :aggregate_failures do
    expect(described_class::KINDS.keys).to match_array(NetworkCheck.kinds.keys)
    expect { described_class.dump("nmap", {}) }.to raise_error(KeyError)
    expect { described_class.load("nmap", {}) }.to raise_error(KeyError)
  end
end
