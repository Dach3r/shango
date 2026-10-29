require "rails_helper"

RSpec.describe Network::EmailChecks::Lookup do
  def answer(status)
    Network::Dns::Query::Answer.new(status:, answers: [], ttl: nil, ms: 1)
  end

  it "asks the fixed public resolver" do
    allow(Network::Dns::Query).to receive(:call).and_return(answer(:ok))
    described_class.call("example.com", "TXT")

    expect(Network::Dns::Query).to have_received(:call).with(ip: Network::Dns::Resolvers::LOOKUP_IP, name: "example.com", type: "TXT", timeout: described_class::TIMEOUT)
  end

  it "tells a resolver that failed from one that said the record is not there", :aggregate_failures do
    %i[timeout servfail refused error].each { |status| expect(described_class.failed?(answer(status))).to be(true) }
    %i[ok nodata nxdomain cname].each { |status| expect(described_class.failed?(answer(status))).to be(false) }
  end

  it "accepts only well-formed names", :aggregate_failures do
    expect(described_class.name?("_spf.example.com")).to be(true)
    expect(described_class.name?("exa mple.com")).to be(false)
    expect(described_class.name?("a..b")).to be(false)
    expect(described_class.name?("#{"a" * 64}.com")).to be(false)
    expect(described_class.name?("#{Array.new(30) { "abcdefgh" }.join(".")}.com")).to be(false)
  end
end
