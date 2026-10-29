require "rails_helper"

RSpec.describe Network::Target do
  let(:environment) { create(:environment) }

  def call(raw, environment: nil)
    described_class.call(raw:, environment:)
  end

  it "normalizes case, whitespace and the trailing dot", :aggregate_failures do
    result = call("  Example.COM. ")

    expect(result).to be_success
    expect(result.record).to eq("example.com")
  end

  it "accepts IPv4 and IPv6 literals and underscored labels", :aggregate_failures do
    expect(call("203.0.113.9").record).to eq("203.0.113.9")
    expect(call("2001:db8::1").record).to eq("2001:db8::1")
    expect(call("_dmarc.example.com").record).to eq("_dmarc.example.com")
  end

  it "resolves variables from the environment", :aggregate_failures do
    create(:variable, environment:, key: "host", value: "Api.Example.com")
    result = call("{{host}}", environment:)

    expect(result).to be_success
    expect(result.record).to eq("api.example.com")
  end

  it "fails when the input is blank" do
    expect(call("  ").error).to eq(:blank)
    expect(call("https://").error).to eq(:blank)
  end

  it "fails on undefined variables, naming the variable", :aggregate_failures do
    result = call("{{missing}}", environment:)

    expect(result.error).to eq(:unresolved_variable)
    expect(result.data[:name]).to eq("missing")
  end

  it "does not see variables without an environment" do
    expect(call("{{host}}").error).to eq(:unresolved_variable)
  end

  it "ignores disabled variables" do
    create(:variable, environment:, key: "host", value: "example.com", enabled: false)

    expect(call("{{host}}", environment:).error).to eq(:unresolved_variable)
  end

  it "refuses secret variables", :aggregate_failures do
    create(:variable, :secret, environment:, key: "host", value: "example.com")
    result = call("{{host}}", environment:)

    expect(result.error).to eq(:secret_variable)
    expect(result.data[:name]).to eq("host")
  end

  it "accepts a pasted URL, dropping scheme, path, query and fragment", :aggregate_failures do
    ["https://www.webcds.cl/", "http://www.webcds.cl", "HTTPS://www.webcds.cl/a/b?q=1#x", "www.webcds.cl/", "www.webcds.cl", "www.webcds.cl?x=1", "www.webcds.cl#top"].each do |raw|
      expect(call(raw).record).to eq("www.webcds.cl"), raw
    end
  end

  it "rejects other schemes, ports and spaces", :aggregate_failures do
    ["ftp://example.com", "example.com:443", "https://example.com:443/", "exa mple.com", "-bad.example.com", "a..b"].each do |raw|
      expect(call(raw).error).to eq(:invalid), raw
    end
  end

  it "rejects names that are too long", :aggregate_failures do
    expect(call("#{"a" * 64}.com").error).to eq(:invalid)
    expect(call(Array.new(30) { "abcdefghi" }.join(".")).error).to eq(:invalid)
  end
end
