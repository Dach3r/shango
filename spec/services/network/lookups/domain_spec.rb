require "rails_helper"

RSpec.describe Network::Lookups::Domain do
  let(:deadline) { Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10 }
  let(:expires) { 200.days.from_now.utc.iso8601 }
  let(:rdap) do
    {
      "ldhName" => "EXAMPLE.COM",
      "status" => ["client transfer prohibited", "client delete prohibited"],
      "events" => [{ "eventAction" => "registration", "eventDate" => "1995-08-14T04:00:00Z" }, { "eventAction" => "expiration", "eventDate" => expires },
                   { "eventAction" => "last changed", "eventDate" => "2026-08-14T08:01:43Z" }],
      "nameservers" => [{ "ldhName" => "A.IANA-SERVERS.NET" }, { "ldhName" => "B.IANA-SERVERS.NET" }, { "unicodeName" => "no-ldh.example" }, "junk"],
      "secureDNS" => { "delegationSigned" => true },
      "entities" => [{ "roles" => ["registrar"], "vcardArray" => ["vcard", [["fn", {}, "text", "RESERVED-IANA"]]], "publicIds" => [{ "type" => "IANA Registrar ID", "identifier" => "376" }],
                       "entities" => [{ "roles" => ["abuse"], "vcardArray" => ["vcard", [["email", {}, "text", "abuse@iana.example"]]] }] },
                     { "roles" => ["registrant"], "vcardArray" => ["vcard", [["fn", {}, "text", "Private Person"]]] }]
    }
  end

  def success(json = rdap)
    Result.success(json)
  end

  def run(host = "example.com")
    described_class.call(host:, deadline:)
  end

  before do
    allow(Network::Rdap::Bootstrap).to receive(:call).and_return(Result.success("https://rdap.example.net/"))
    allow(Network::Rdap::Client).to receive(:call).and_return(success)
  end

  it "describes the registration of a domain", :aggregate_failures do
    result = run

    expect(result).to be_success
    expect(result.data).to include(host: "example.com", type: "domain", network: nil, asn: [], findings: [])
    expect(result.data[:domain]).to eq(
      name: "example.com", queried: "example.com", registrar: { name: "RESERVED-IANA", iana_id: "376" }, abuse: { email: "abuse@iana.example", phone: nil },
      registered: "1995-08-14T04:00:00Z", expires:, updated: "2026-08-14T08:01:43Z", days_left: 199, statuses: ["client transfer prohibited", "client delete prohibited"],
      nameservers: %w[a.iana-servers.net b.iana-servers.net], dnssec: true
    )
    expect(Network::Rdap::Client).to have_received(:call).with(url: "https://rdap.example.net/domain/example.com", deadline:)
    expect(Network::Rdap::Bootstrap).to have_received(:call).with(kind: :dns, key: "com", deadline:)
  end

  it "never keeps registrant data", :aggregate_failures do
    data = run.data.to_json

    expect(data).not_to include("Private Person")
  end

  it "reports a domain that expired or expires soon", :aggregate_failures do
    allow(Network::Rdap::Client).to receive(:call).and_return(success(rdap.merge("events" => [{ "eventAction" => "expiration", "eventDate" => 3.days.ago.utc.iso8601 }])))

    expect(run.data[:findings].pluck(:key)).to eq(%w[expired])
    expect(run.data[:findings].first).to include(tone: "bad", args: { date: 3.days.ago.utc.to_date.iso8601 })

    allow(Network::Rdap::Client).to receive(:call).and_return(success(rdap.merge("events" => [{ "eventAction" => "expiration", "eventDate" => 10.days.from_now.utc.iso8601 }])))

    expect(run.data[:findings].pluck(:key, :tone)).to eq([%w[expiring warn]])
  end

  it "reports a domain on hold or about to be deleted", :aggregate_failures do
    allow(Network::Rdap::Client).to receive(:call).and_return(success(rdap.merge("status" => ["client hold"])))

    expect(run.data[:findings].pluck(:key)).to eq(%w[hold])

    allow(Network::Rdap::Client).to receive(:call).and_return(success(rdap.merge("status" => ["redemption period", "serverHold"])))

    expect(run.data[:findings].pluck(:key)).to eq(%w[hold pending_delete])
  end

  it "copes with a registry that gives little", :aggregate_failures do
    allow(Network::Rdap::Client).to receive(:call).and_return(success("status" => "active", "secureDNS" => "none"))
    domain = run.data[:domain]

    expect(domain).to include(name: "example.com", registrar: nil, abuse: nil, expires: nil, days_left: nil, statuses: ["active"], nameservers: [], dnssec: nil)
    expect(run.data[:findings]).to be_empty
  end

  it "reads an unsigned zone" do
    allow(Network::Rdap::Client).to receive(:call).and_return(success(rdap.merge("secureDNS" => { "delegationSigned" => false })))

    expect(run.data[:domain][:dnssec]).to be(false)
  end

  it "cuts what a registry lists", :aggregate_failures do
    allow(Network::Rdap::Client).to receive(:call).and_return(success(rdap.merge("nameservers" => Array.new(30) { |index| { "ldhName" => "ns#{index}.example.net" } }, "status" => Array.new(30) { |index| "s#{index}" })))

    expect(run.data[:domain][:nameservers].size).to eq(described_class::MAX_LISTED)
    expect(run.data[:domain][:statuses].size).to eq(described_class::MAX_LISTED)
  end

  it "finds the registered domain of a subdomain by dropping labels", :aggregate_failures do
    allow(Network::Rdap::Client).to receive(:call).with(hash_including(url: "https://rdap.example.net/domain/www.example.com")).and_return(Result.failure(error: :not_found))
    result = run("www.example.com")

    expect(result.data[:domain]).to include(name: "example.com", queried: "example.com")
    expect(result.data[:host]).to eq("www.example.com")
  end

  it "tries no more than a few names" do
    allow(Network::Rdap::Client).to receive(:call).and_return(Result.failure(error: :not_found))

    expect(run("a.b.c.d.e.example.com")).to have_attributes(failure?: true, error: :not_registered)
    expect(Network::Rdap::Client).to have_received(:call).exactly(described_class::MAX_CANDIDATES).times
  end

  it "asks about a single label as it is" do
    allow(Network::Rdap::Client).to receive(:call).and_return(Result.failure(error: :not_found))

    expect(run("localhost")).to have_attributes(failure?: true, error: :not_registered)
    expect(Network::Rdap::Client).to have_received(:call).with(hash_including(url: "https://rdap.example.net/domain/localhost"))
  end

  it "fails when the registry has no RDAP service", :aggregate_failures do
    allow(Network::Rdap::Bootstrap).to receive(:call).and_return(Result.failure(error: :no_rdap_service))

    expect(run).to have_attributes(failure?: true, error: :no_rdap_service)
    expect(Network::Rdap::Client).not_to have_received(:call)
  end

  it "fails when the service does not answer, without trying other names" do
    allow(Network::Rdap::Client).to receive(:call).and_return(Result.failure(error: :unavailable))

    expect(run("www.example.com")).to have_attributes(failure?: true, error: :rdap_unavailable)
    expect(Network::Rdap::Client).to have_received(:call).once
  end
end
