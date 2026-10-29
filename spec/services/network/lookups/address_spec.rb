require "rails_helper"

RSpec.describe Network::Lookups::Address do
  let(:deadline) { Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10 }
  let(:ip) { IPAddr.new("8.8.8.8") }
  let(:rdap) do
    {
      "name" => "GOGL", "handle" => "NET-8-8-8-0-2", "type" => "DIRECT ALLOCATION", "country" => "US", "startAddress" => "8.8.8.0", "endAddress" => "8.8.8.255",
      "cidr0_cidrs" => [{ "v4prefix" => "8.8.8.0", "length" => 24 }, { "v6prefix" => "2001:db8::", "length" => 32 }, { "length" => 8 }, "junk"],
      "events" => [{ "eventAction" => "last changed", "eventDate" => "2023-12-28T22:24:56Z" }],
      "entities" => [{ "roles" => ["registrant"], "vcardArray" => ["vcard", [["fn", {}, "text", "Google LLC"], ["kind", {}, "text", "org"]]] },
                     { "roles" => ["abuse"], "vcardArray" => ["vcard", [["email", {}, "text", "network-abuse@google.com"]]] }]
    }
  end
  let(:origin) { { number: "15169", name: "GOOGLE, US", prefix: "8.8.8.0/24", country: "US", registry: "arin", allocated: "2023-12-28" } }

  def run(address = ip)
    described_class.call(ip: address, host: address.to_s, deadline:)
  end

  before do
    allow(Network::Rdap::Bootstrap).to receive(:call).and_return(Result.success("https://rdap.example.net/"))
    allow(Network::Rdap::Client).to receive(:call).and_return(Result.success(rdap))
    allow(Network::Lookups::Asn).to receive(:call).and_return(Result.success([origin]))
  end

  it "describes the network and the autonomous system", :aggregate_failures do
    result = run

    expect(result).to be_success
    expect(result.data).to include(host: "8.8.8.8", type: "ip", domain: nil, asn: [origin], findings: [])
    expect(result.data[:network]).to eq(
      name: "GOGL", handle: "NET-8-8-8-0-2", type: "DIRECT ALLOCATION", country: "US", range: "8.8.8.0 - 8.8.8.255", cidrs: ["8.8.8.0/24", "2001:db8::/32"],
      organization: "Google LLC", abuse: { email: "network-abuse@google.com", phone: nil }, updated: "2023-12-28T22:24:56Z"
    )
    expect(Network::Rdap::Client).to have_received(:call).with(url: "https://rdap.example.net/ip/8.8.8.8", deadline:)
    expect(Network::Rdap::Bootstrap).to have_received(:call).with(kind: :ipv4, key: ip, deadline:)
  end

  it "uses the IPv6 registry for an IPv6 address" do
    run(IPAddr.new("2606:4700:4700::1111"))

    expect(Network::Rdap::Bootstrap).to have_received(:call).with(hash_including(kind: :ipv6))
  end

  it "copes with a network that gives little", :aggregate_failures do
    allow(Network::Rdap::Client).to receive(:call).and_return(Result.success({ "name" => "X" }))

    expect(run.data[:network]).to include(name: "X", range: nil, cidrs: [], organization: nil, abuse: nil, updated: nil)
  end

  it "keeps the autonomous system when RDAP failed, and says so", :aggregate_failures do
    allow(Network::Rdap::Client).to receive(:call).and_return(Result.failure(error: :unavailable))
    result = run

    expect(result).to be_success
    expect(result.data[:network]).to be_nil
    expect(result.data[:findings]).to eq([{ key: "rdap_failed", tone: "warn", args: {} }])
  end

  it "keeps the network when the autonomous system could not be read, and says so", :aggregate_failures do
    allow(Network::Lookups::Asn).to receive(:call).and_return(Result.failure(error: :unavailable))
    result = run

    expect(result.data).to include(asn: [])
    expect(result.data[:findings]).to eq([{ key: "asn_unavailable", tone: "warn", args: {} }])
  end

  it "warns about an address nobody announces" do
    allow(Network::Lookups::Asn).to receive(:call).and_return(Result.success([]))

    expect(run.data[:findings]).to eq([{ key: "not_announced", tone: "warn", args: {} }])
  end

  it "fails when nothing answered, naming the reason", :aggregate_failures do
    allow(Network::Lookups::Asn).to receive(:call).and_return(Result.failure(error: :unavailable))
    allow(Network::Rdap::Bootstrap).to receive(:call).and_return(Result.failure(error: :no_rdap_service))

    expect(run).to have_attributes(failure?: true, error: :no_rdap_service)

    allow(Network::Rdap::Bootstrap).to receive(:call).and_return(Result.failure(error: :unavailable))

    expect(run).to have_attributes(failure?: true, error: :rdap_unavailable)
  end
end
