require "rails_helper"

RSpec.describe Network::PortChecks::PortSpec do
  def ports(raw)
    described_class.call(raw:)
  end

  it "parses numbers separated by commas and spaces, sorted and unique", :aggregate_failures do
    result = ports("443, 80  22,80")

    expect(result).to be_success
    expect(result.record).to eq([22, 80, 443])
  end

  it "expands ranges" do
    expect(ports("8000-8003").record).to eq([8000, 8001, 8002, 8003])
  end

  it "accepts a single-port range" do
    expect(ports("22-22").record).to eq([22])
  end

  it "expands the common preset in any case, merged with other ports", :aggregate_failures do
    expect(ports("Common").record).to eq(described_class::COMMON.sort)
    expect(ports("common, 9999").record).to include(9999, 22)
  end

  it "fails when there is nothing to check", :aggregate_failures do
    expect(ports("").error).to eq(:blank_ports)
    expect(ports(" , ").error).to eq(:blank_ports)
    expect(ports(nil).error).to eq(:blank_ports)
  end

  it "fails on invalid tokens, naming the token", :aggregate_failures do
    ["abc", "0", "65536", "-5", "80-", "10-5", "70000-70010", "80-99999", "1.5"].each do |raw|
      result = ports("22, #{raw}")

      expect(result.error).to eq(:invalid_ports), raw
      expect(result.data[:token]).to eq(raw)
    end
  end

  it "truncates very long invalid tokens" do
    expect(ports("x" * 50).data[:token].length).to be <= 20
  end

  it "accepts exactly the maximum number of ports" do
    expect(ports("1-#{described_class::MAX_PORTS}").record.size).to eq(described_class::MAX_PORTS)
  end

  it "fails above the maximum, reporting it", :aggregate_failures do
    result = ports("1-#{described_class::MAX_PORTS + 1}")

    expect(result.error).to eq(:too_many_ports)
    expect(result.data[:max]).to eq(described_class::MAX_PORTS)
  end

  it "fails early when accumulated ports exceed the maximum" do
    expect(ports("1-60, 100-160").error).to eq(:too_many_ports)
  end
end
