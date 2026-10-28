require "rails_helper"

RSpec.describe Network::DnsChecks::Run do
  let(:authoritative) { Network::Dns::Resolvers::Resolver.new(name: "ns1.example.net", ip: "192.0.2.1", group: :authoritative) }
  let(:public_resolvers) { Network::Dns::Resolvers::PUBLIC.first(2) }

  def answer(status = :ok, *answers)
    Network::Dns::Query::Answer.new(status:, answers:, ttl: 60, ms: 12)
  end

  def stub_resolvers(authoritative_resolvers = [authoritative])
    allow(Network::Dns::Resolvers).to receive(:authoritative).and_return(authoritative_resolvers)
    stub_const("Network::Dns::Resolvers::PUBLIC", public_resolvers)
  end

  def stub_answers(by_ip)
    allow(Network::Dns::Query).to receive(:call) { |ip:, **| by_ip.fetch(ip) }
  end

  def run(**options)
    described_class.call(domain: "Example.com", type: "a", **options)
  end

  before { stub_resolvers }

  it "queries the authoritative nameservers first, then the public resolvers", :aggregate_failures do
    stub_answers("192.0.2.1" => answer(:ok, "203.0.113.10"), "8.8.8.8" => answer(:ok, "203.0.113.10"), "1.1.1.1" => answer(:timeout))
    result = run

    expect(result).to be_success
    expect(result.data[:host]).to eq("example.com")
    expect(result.data[:type]).to eq("A")
    expect(result.data[:rows].map { |row| [row.name, row.group, row.status] })
      .to eq([["ns1.example.net", :authoritative, :ok], ["Google", :public, :ok], ["Cloudflare", :public, :timeout]])
    expect(Network::Dns::Query).to have_received(:call).with(hash_including(name: "example.com", type: "A", timeout: described_class::TIMEOUT)).exactly(3).times
  end

  it "summarizes how many resolvers answered and whether they agree", :aggregate_failures do
    stub_answers("192.0.2.1" => answer(:ok, "203.0.113.10"), "8.8.8.8" => answer(:ok, "203.0.113.10"), "1.1.1.1" => answer(:timeout))

    expect(run.data[:summary]).to eq(total: 3, answered: 2, matched: 0, agree: true)
    expect(run.data[:expected]).to be_nil
  end

  it "reports disagreement between resolvers" do
    stub_answers("192.0.2.1" => answer(:ok, "203.0.113.10"), "8.8.8.8" => answer(:ok, "198.51.100.7"), "1.1.1.1" => answer(:ok, "203.0.113.10"))

    expect(run.data[:summary][:agree]).to be(false)
  end

  describe "with an expected value" do
    before { stub_answers("192.0.2.1" => answer(:ok, "203.0.113.10"), "8.8.8.8" => answer(:ok, "198.51.100.7"), "1.1.1.1" => answer(:nodata)) }

    it "marks each row and counts the matches", :aggregate_failures do
      result = run(expected: " 203.0.113.10 ")

      expect(result.data[:rows].map(&:match)).to eq(%i[match mismatch no_answer])
      expect(result.data[:summary][:matched]).to eq(1)
      expect(result.data[:expected]).to eq("203.0.113.10")
    end

    it "ignores case, quotes and the trailing dot", :aggregate_failures do
      stub_answers("192.0.2.1" => answer(:ok, "Target.Example.net"), "8.8.8.8" => answer(:ok, "v=spf1 -all"), "1.1.1.1" => answer(:cname, "target.example.net"))

      expect(run(expected: "target.example.net.").data[:rows].map(&:match)).to eq(%i[match mismatch match])
      expect(run(expected: '"V=SPF1 -all"').data[:rows].map(&:match)).to eq(%i[mismatch match mismatch])
    end
  end

  describe "reverse DNS" do
    def stub_ptr(name: "dns.google", forward: answer(:ok, "8.8.8.8"))
      allow(Network::Dns::Query).to receive(:call) { |type:, **| type == "PTR" ? answer(:ok, "#{name}.") : forward }
    end

    it "asks for the in-addr.arpa name of an IPv4 address and confirms the names it points to", :aggregate_failures do
      stub_ptr
      result = described_class.call(domain: "8.8.8.8", type: "ptr")

      expect(result.data).to include(host: "8.8.8.8", type: "PTR", reverse: "8.8.8.8.in-addr.arpa")
      expect(result.data[:forward]).to eq([{ name: "dns.google", addresses: ["8.8.8.8"], confirmed: true }])
      expect(Network::Dns::Resolvers).to have_received(:authoritative).with("8.8.8.8.in-addr.arpa")
      expect(Network::Dns::Query).to have_received(:call).with(hash_including(name: "8.8.8.8.in-addr.arpa", type: "PTR")).exactly(3).times
    end

    it "asks for the ip6.arpa name of an IPv6 address" do
      stub_ptr(forward: answer(:ok, "2001:4860:4860::8888"))
      result = described_class.call(domain: "2001:4860:4860::8888", type: "PTR")

      expect(result.data[:reverse]).to eq("8.8.8.8.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.6.8.4.0.6.8.4.1.0.0.2.ip6.arpa")
    end

    it "matches the expected name without the trailing dot" do
      stub_ptr

      expect(described_class.call(domain: "8.8.8.8", type: "PTR", expected: "dns.google").data[:summary][:matched]).to eq(3)
    end

    it "has nothing to confirm when no resolver answered" do
      stub_answers("192.0.2.1" => answer(:nxdomain), "8.8.8.8" => answer(:timeout), "1.1.1.1" => answer(:nxdomain))

      expect(described_class.call(domain: "192.0.2.55", type: "PTR").data[:forward]).to eq([])
    end

    it "refuses a host name", :aggregate_failures do
      result = described_class.call(domain: "example.com", type: "PTR")

      expect(result).to be_failure
      expect(result.error).to eq(:ptr_needs_ip)
    end

    it "keeps other types free of reverse data" do
      stub_answers("192.0.2.1" => answer, "8.8.8.8" => answer, "1.1.1.1" => answer)

      expect(run.data.keys).not_to include(:reverse, :forward)
    end
  end

  describe "rows that are not queried" do
    it "marks nameservers without an address", :aggregate_failures do
      stub_resolvers([Network::Dns::Resolvers::Resolver.new(name: "ns9.example.net", ip: nil, group: :authoritative)])
      stub_answers("8.8.8.8" => answer, "1.1.1.1" => answer)
      row = run.data[:rows].first

      expect(row.status).to eq(:unresolved)
      expect(row.answers).to eq([])
      expect(row.ms).to be_nil
      expect(Network::Dns::Query).to have_received(:call).twice
    end

    it "refuses nameservers inside blocked ranges when the guard is on", :aggregate_failures do
      stub_resolvers([Network::Dns::Resolvers::Resolver.new(name: "evil.example.net", ip: "169.254.169.254", group: :authoritative)])
      allow(Network::SsrfPolicy).to receive(:enabled?).and_return(true)
      stub_answers("8.8.8.8" => answer, "1.1.1.1" => answer)

      expect(run.data[:rows].first.status).to eq(:blocked)
      expect(Network::Dns::Query).not_to have_received(:call).with(hash_including(ip: "169.254.169.254"))
    end

    it "queries nameservers in private ranges when the guard is off" do
      stub_resolvers([Network::Dns::Resolvers::Resolver.new(name: "ns.internal", ip: "10.0.0.2", group: :authoritative)])
      stub_answers("10.0.0.2" => answer, "8.8.8.8" => answer, "1.1.1.1" => answer)

      expect(run.data[:rows].first.status).to eq(:ok)
    end
  end

  describe "invalid input" do
    it "rejects unsupported record types", :aggregate_failures do
      result = described_class.call(domain: "example.com", type: "ANY")

      expect(result).to be_failure
      expect(result.error).to eq(:invalid_type)
    end

    it "returns the target error", :aggregate_failures do
      result = described_class.call(domain: "https://example.com", type: "A")

      expect(result).to be_failure
      expect(result.error).to eq(:invalid)
    end

    it "resolves {{variables}} from the environment", :aggregate_failures do
      environment = create(:environment)
      create(:variable, environment:, key: "host", value: "api.example.com")
      stub_answers("192.0.2.1" => answer, "8.8.8.8" => answer, "1.1.1.1" => answer)
      result = described_class.call(domain: "{{host}}", type: "A", environment:)

      expect(result.data[:host]).to eq("api.example.com")
      expect(Network::Dns::Resolvers).to have_received(:authoritative).with("api.example.com")
    end
  end
end
