require "rails_helper"

RSpec.describe Network::Rdap::Bootstrap do
  let(:dns) { { "services" => [[%w[com net], ["https://rdap.verisign.com/com/v1/"]], [%w[io], ["http://insecure.example/", "https://rdap.example.io"]], [%w[xx], ["http://only-http.example/"]]] } }
  let(:ipv4) { { "services" => [[%w[8.0.0.0/8], ["https://rdap.arin.net/registry/"]], [%w[8.8.8.0/24], ["https://rdap.google.example/"]], [%w[bogus], ["https://rdap.bad.example/"]], %w[junk]] } }

  def stub_bootstrap(file, body, **response)
    stub_request(:get, "https://data.iana.org/rdap/#{file}.json").to_return({ status: 200, body: body.to_json }.merge(response))
  end

  it "finds the server of a top-level domain", :aggregate_failures do
    stub_bootstrap("dns", dns)

    expect(described_class.call(kind: :dns, key: "com").record).to eq("https://rdap.verisign.com/com/v1/")
    expect(described_class.call(kind: :dns, key: "io").record).to eq("https://rdap.example.io/")
  end

  it "has no service for a domain the registry does not list, or lists without HTTPS", :aggregate_failures do
    stub_bootstrap("dns", dns)

    expect(described_class.call(kind: :dns, key: "zz")).to have_attributes(failure?: true, error: :no_rdap_service)
    expect(described_class.call(kind: :dns, key: "xx")).to have_attributes(failure?: true, error: :no_rdap_service)
  end

  it "finds the server of the most specific network that holds an address", :aggregate_failures do
    stub_bootstrap("ipv4", ipv4)

    expect(described_class.call(kind: :ipv4, key: IPAddr.new("8.8.8.8")).record).to eq("https://rdap.google.example/")
    expect(described_class.call(kind: :ipv4, key: IPAddr.new("8.1.1.1")).record).to eq("https://rdap.arin.net/registry/")
    expect(described_class.call(kind: :ipv4, key: IPAddr.new("9.9.9.9"))).to have_attributes(failure?: true, error: :no_rdap_service)
  end

  it "fails when the registry cannot be read or has nothing usable", :aggregate_failures do
    stub_bootstrap("dns", {}, status: 500)

    expect(described_class.call(kind: :dns, key: "com")).to have_attributes(failure?: true, error: :unavailable)

    stub_bootstrap("dns", { "services" => ["junk"] })

    expect(described_class.call(kind: :dns, key: "com")).to have_attributes(failure?: true, error: :unavailable)
  end

  describe "caching" do
    before { allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new) }

    it "keeps each registry for a day", :aggregate_failures do
      stub = stub_bootstrap("dns", dns)
      2.times { described_class.call(kind: :dns, key: "com") }

      expect(stub).to have_been_requested.once
      expect(Rails.cache.read("network/rdap/bootstrap/dns")).to eq(dns["services"])
    end

    it "does not keep a registry it could not read" do
      stub_bootstrap("dns", {}, status: 500)
      described_class.call(kind: :dns, key: "com")

      expect(Rails.cache.read("network/rdap/bootstrap/dns")).to be_nil
    end
  end
end
