require "rails_helper"

RSpec.describe Network::DnsChecks::ForwardConfirmation do
  def answer(status = :ok, *answers)
    Network::Dns::Query::Answer.new(status:, answers:, ttl: 60, ms: 12)
  end

  def stub_answers(by_name)
    allow(Network::Dns::Query).to receive(:call) { |name:, **| by_name.fetch(name) }
  end

  it "confirms the names that resolve back to the address", :aggregate_failures do
    stub_answers("dns.google" => answer(:ok, "8.8.4.4", "8.8.8.8"), "other.example" => answer(:ok, "203.0.113.9"))

    expect(described_class.call(ip: "8.8.8.8", names: %w[dns.google other.example])).to eq(
      [{ name: "dns.google", addresses: ["8.8.4.4", "8.8.8.8"], confirmed: true },
       { name: "other.example", addresses: ["203.0.113.9"], confirmed: false }]
    )
    expect(Network::Dns::Query).to have_received(:call).with(hash_including(ip: Network::Dns::Resolvers::LOOKUP_IP, type: "A")).twice
  end

  it "asks for AAAA records of an IPv6 address and compares them normalized", :aggregate_failures do
    stub_answers("dns.google" => answer(:ok, "2001:4860:4860:0:0:0:0:8888"))

    expect(described_class.call(ip: "2001:4860:4860::8888", names: ["dns.google"]).first[:confirmed]).to be(true)
    expect(Network::Dns::Query).to have_received(:call).with(hash_including(type: "AAAA"))
  end

  it "does not confirm a name without addresses, even behind an alias" do
    stub_answers("gone.example" => answer(:nxdomain), "alias.example" => answer(:cname, "8.8.8.8"))

    expect(described_class.call(ip: "8.8.8.8", names: %w[gone.example alias.example]))
      .to all(include(addresses: [], confirmed: false))
  end

  it "checks at most a few names" do
    stub_answers(Array.new(5) { |index| ["host#{index}.example", answer(:nodata)] }.to_h)

    expect(described_class.call(ip: "8.8.8.8", names: Array.new(5) { |index| "host#{index}.example" }).size).to eq(described_class::LIMIT)
  end
end
