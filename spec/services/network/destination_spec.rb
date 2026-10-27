require "rails_helper"

RSpec.describe Network::Destination do
  def addrinfo(*addresses)
    addresses.map { |address| instance_double(Addrinfo, ip_address: address) }
  end

  it "returns the address approved by the policy" do
    allow(Network::SsrfPolicy).to receive(:check!).with("example.com").and_return("93.184.216.34")

    expect(described_class.call(host: "example.com").record).to eq("93.184.216.34")
  end

  it "resolves the host itself when the policy is off" do
    allow(Network::SsrfPolicy).to receive(:check!).and_return(nil)
    allow(Addrinfo).to receive(:getaddrinfo).with("example.com", nil, nil, :STREAM).and_return(addrinfo("93.184.216.34", "2606:2800::1"))

    expect(described_class.call(host: "example.com").record).to eq("93.184.216.34")
  end

  it "fails with blocked when the policy refuses the host", :aggregate_failures do
    allow(Network::SsrfPolicy).to receive(:check!).and_raise(Network::SsrfPolicy::Blocked, "internal resolves to a private address (10.0.0.1)")
    result = described_class.call(host: "internal")

    expect(result).to be_failure
    expect(result.error).to eq(:blocked)
    expect(result.data[:detail]).to include("10.0.0.1")
  end

  it "fails with unresolved when the name does not resolve" do
    allow(Network::SsrfPolicy).to receive(:check!).and_return(nil)
    allow(Addrinfo).to receive(:getaddrinfo).and_raise(SocketError)

    expect(described_class.call(host: "nope.invalid").error).to eq(:unresolved)
  end
end
