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

  it "settles a run without expected value when the answers agree, and warns when they differ", :aggregate_failures do
    expect(dns({ total: 2, answered: 2, matched: 0, agree: true }).tone).to eq("ok")
    expect(dns({ total: 2, answered: 2, matched: 0, agree: false }).tone).to eq("warn")
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
end
