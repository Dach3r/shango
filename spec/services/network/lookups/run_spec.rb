require "rails_helper"

RSpec.describe Network::Lookups::Run do
  let(:found) { Result.success(nil, host: "example.com", type: "domain", domain: {}, network: nil, asn: [], findings: []) }

  before do
    allow(Network::Lookups::Domain).to receive(:call).and_return(found)
    allow(Network::Lookups::Address).to receive(:call).and_return(found)
  end

  it "looks up a domain, after cleaning the typed host", :aggregate_failures do
    expect(described_class.call(host: " https://Example.com/path ")).to eq(found)
    expect(Network::Lookups::Domain).to have_received(:call).with(host: "example.com", deadline: a_kind_of(Float))
  end

  it "looks up an IP address", :aggregate_failures do
    expect(described_class.call(host: "8.8.8.8")).to eq(found)
    expect(Network::Lookups::Address).to have_received(:call).with(ip: IPAddr.new("8.8.8.8"), host: "8.8.8.8", deadline: a_kind_of(Float))
  end

  it "turns an IPv4-mapped IPv6 address into the IPv4 address" do
    described_class.call(host: "::ffff:8.8.8.8")

    expect(Network::Lookups::Address).to have_received(:call).with(hash_including(ip: IPAddr.new("8.8.8.8")))
  end

  it "has no public data for private, loopback or reserved addresses", :aggregate_failures do
    %w[10.0.0.1 127.0.0.1 169.254.169.254 ::1 fe80::1].each do |address|
      expect(described_class.call(host: address)).to have_attributes(failure?: true, error: :private_address)
    end
    expect(Network::Lookups::Address).not_to have_received(:call)
  end

  it "refuses an invalid target and an undefined variable", :aggregate_failures do
    expect(described_class.call(host: "bad host!")).to have_attributes(failure?: true, error: :invalid)
    expect(described_class.call(host: "{{nope}}")).to have_attributes(failure?: true, error: :unresolved_variable)
  end

  it "reads variables" do
    environment = create(:environment)
    create(:variable, environment:, key: "site", value: "example.com")
    described_class.call(host: "{{site}}", environment:)

    expect(Network::Lookups::Domain).to have_received(:call).with(hash_including(host: "example.com"))
  end

  it "never contacts the target, only registries and the fixed resolver" do
    allow(Network::Destination).to receive(:call)
    described_class.call(host: "example.com")

    expect(Network::Destination).not_to have_received(:call)
  end
end
