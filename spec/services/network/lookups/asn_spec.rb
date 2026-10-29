require "rails_helper"

RSpec.describe Network::Lookups::Asn do
  def answer(*records, status: records.empty? ? :nodata : :ok)
    Network::Dns::Query::Answer.new(status:, answers: records, ttl: 60, ms: 1)
  end

  def stub_dns(records)
    allow(Network::Dns::Lookup).to receive(:call) { |name, _type| records.fetch(name) { answer } }
  end

  it "reads the origin and the name of an IPv4 address", :aggregate_failures do
    stub_dns("8.8.8.8.origin.asn.cymru.com" => answer("15169 | 8.8.8.0/24 | US | arin | 2023-12-28"), "AS15169.asn.cymru.com" => answer("15169 | US | arin | 2000-03-30 | GOOGLE, US"))
    result = described_class.call(ip: IPAddr.new("8.8.8.8"))

    expect(result.record).to eq([{ number: "15169", name: "GOOGLE, US", prefix: "8.8.8.0/24", country: "US", registry: "arin", allocated: "2023-12-28" }])
  end

  it "asks about an IPv6 address by its nibbles", :aggregate_failures do
    ip = IPAddr.new("2606:4700::1111")
    stub_dns("#{ip.reverse.delete_suffix(".ip6.arpa")}.origin6.asn.cymru.com" => answer("13335 | 2606:4700::/32 | US | arin | 2011-11-01"))

    expect(described_class.call(ip:).record.first).to include(number: "13335", name: nil, prefix: "2606:4700::/32")
    expect(Network::Dns::Lookup).to have_received(:call).with(a_string_matching(/\A(\h\.){32}origin6\.asn\.cymru\.com\z/), "TXT")
  end

  it "keeps the first origins when several announce the address", :aggregate_failures do
    stub_dns("4.4.4.4.origin.asn.cymru.com" => answer("1 2 3 4 | 4.0.0.0/9 | US | arin | 1992-12-01"))
    result = described_class.call(ip: IPAddr.new("4.4.4.4"))

    expect(result.record.pluck(:number)).to eq(%w[1 2 3])
  end

  it "has no origin for an address nobody announces, and ignores a reply it cannot read", :aggregate_failures do
    stub_dns({})

    expect(described_class.call(ip: IPAddr.new("203.0.113.9")).record).to eq([])

    stub_dns("203.0.113.9.origin.asn.cymru.com" => answer("NA"))

    expect(described_class.call(ip: IPAddr.new("203.0.113.9")).record).to eq([])
  end

  it "fails when the resolver could not answer" do
    allow(Network::Dns::Lookup).to receive(:call).and_return(answer(status: :timeout))

    expect(described_class.call(ip: IPAddr.new("8.8.8.8"))).to have_attributes(failure?: true, error: :unavailable)
  end
end
