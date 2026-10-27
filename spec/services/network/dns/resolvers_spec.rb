require "rails_helper"

RSpec.describe Network::Dns::Resolvers do
  def answer(status, *answers)
    Network::Dns::Query::Answer.new(status:, answers:, ttl: 60, ms: 5)
  end

  def stub_query(name, type, result)
    allow(Network::Dns::Query).to receive(:call).with(hash_including(name:, type:)).and_return(result)
  end

  describe "PUBLIC" do
    it "lists distinct public resolvers", :aggregate_failures do
      expect(described_class::PUBLIC.map(&:ip).uniq.size).to eq(described_class::PUBLIC.size)
      expect(described_class::PUBLIC.map(&:group).uniq).to eq([:public])
      expect(described_class::PUBLIC.none? { |resolver| Network::SsrfPolicy.blocked?(resolver.ip) }).to be(true)
    end
  end

  describe ".authoritative" do
    it "returns the nameservers of the domain with their addresses", :aggregate_failures do
      stub_query("example.com", "NS", answer(:ok, "NS1.Example.net.", "ns2.example.net"))
      stub_query("ns1.example.net", "A", answer(:ok, "192.0.2.1"))
      stub_query("ns2.example.net", "A", answer(:ok, "192.0.2.2"))

      expect(described_class.authoritative("example.com").map { |resolver| [resolver.name, resolver.ip, resolver.group] })
        .to eq([["ns1.example.net", "192.0.2.1", :authoritative], ["ns2.example.net", "192.0.2.2", :authoritative]])
    end

    it "walks up to the zone when the name has no NS records of its own", :aggregate_failures do
      stub_query("www.example.com", "NS", answer(:nodata))
      stub_query("example.com", "NS", answer(:ok, "ns1.example.net"))
      stub_query("ns1.example.net", "A", answer(:ok, "192.0.2.1"))

      expect(described_class.authoritative("www.example.com").map(&:name)).to eq(["ns1.example.net"])
    end

    it "falls back to IPv6 and keeps a nameserver without address", :aggregate_failures do
      stub_query("example.com", "NS", answer(:ok, "ns1.example.net", "ns2.example.net"))
      stub_query("ns1.example.net", "A", answer(:nodata))
      stub_query("ns1.example.net", "AAAA", answer(:ok, "2001:db8::1"))
      stub_query("ns2.example.net", "A", answer(:timeout))
      stub_query("ns2.example.net", "AAAA", answer(:nodata))

      expect(described_class.authoritative("example.com").map(&:ip)).to eq(["2001:db8::1", nil])
    end

    it "tries a single-label name once" do
      stub_query("localhost", "NS", answer(:nodata))

      expect(described_class.authoritative("localhost")).to eq([])
    end

    it "returns nothing when no nameserver can be found" do
      stub_query("example.com", "NS", answer(:timeout))

      expect(described_class.authoritative("example.com")).to eq([])
    end
  end
end
