require "rails_helper"

RSpec.describe Network::EmailChecks::Mx do
  def answer(*records, status: records.empty? ? :nodata : :ok)
    Network::Dns::Query::Answer.new(status:, answers: records, ttl: 60, ms: 1)
  end

  def check(records)
    allow(Network::Dns::Lookup).to receive(:call) { |name, type| records.fetch([name, type]) { answer } }
    described_class.call(domain: "example.com")
  end

  it "lists the servers by preference and checks that each resolves", :aggregate_failures do
    section = check(["example.com", "MX"] => answer("20 Mx2.example.com.", "10 mx1.example.com"), ["mx1.example.com", "A"] => answer("203.0.113.1"), ["mx2.example.com", "AAAA"] => answer("2001:db8::1"))

    expect(section.data).to eq(null: false, records: [{ preference: 10, exchange: "mx1.example.com", status: "ok" }, { preference: 20, exchange: "mx2.example.com", status: "ok" }])
    expect(section.findings).to be_empty
  end

  it "reports a domain with no MX" do
    expect(check({}).findings).to eq([{ key: "mx.missing", tone: "warn", args: {} }])
  end

  it "says so when the resolver could not answer" do
    section = check(["example.com", "MX"] => answer(status: :servfail))

    expect(section).to have_attributes(data: nil, findings: [{ key: "mx.lookup_failed", tone: "warn", args: { name: "example.com" } }])
  end

  it "understands a null MX as a domain that takes no mail", :aggregate_failures do
    section = check(["example.com", "MX"] => answer("0 ."))

    expect(section.data).to eq(null: true, records: [])
    expect(section.findings).to be_empty
  end

  it "reports a server that is an alias, has no address or is not a valid name", :aggregate_failures do
    section = check(["example.com", "MX"] => answer("10 alias.example.com", "20 gone.example.com", "30 bad name.example.com"), ["alias.example.com", "A"] => answer(status: :cname))

    expect(section.findings).to eq([{ key: "mx.cname", tone: "bad", args: { host: "alias.example.com" } }, { key: "mx.unresolved", tone: "bad", args: { host: "gone.example.com" } },
                                    { key: "mx.unresolved", tone: "bad", args: { host: "bad name.example.com" } }])
  end

  it "warns when the resolver could not tell whether a server resolves" do
    section = check(["example.com", "MX"] => answer("10 slow.example.com"), ["slow.example.com", "A"] => answer(status: :timeout))

    expect(section.findings).to eq([{ key: "mx.lookup_failed", tone: "warn", args: { name: "slow.example.com" } }])
  end

  it "reads only the first servers" do
    stub_const("#{described_class}::MAX_RECORDS", 1)
    section = check(["example.com", "MX"] => answer("20 b.example.com", "10 a.example.com"))

    expect(section.data[:records].pluck(:exchange)).to eq(%w[a.example.com])
  end
end
