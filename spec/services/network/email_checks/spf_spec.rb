require "rails_helper"

RSpec.describe Network::EmailChecks::Spf do
  def answer(*records, status: records.empty? ? :nodata : :ok)
    Network::Dns::Query::Answer.new(status:, answers: records, ttl: 60, ms: 1)
  end

  def stub_records(records)
    allow(Network::EmailChecks::Lookup).to receive(:call) { |name, _type| records.fetch(name) { answer } }
  end

  def check(record, records = {})
    stub_records(records)
    described_class.call(domain: "example.com", answer: answer(*record))
  end

  def keys(section)
    section.findings.pluck(:key)
  end

  it "has nothing to say about a tight record", :aggregate_failures do
    section = check("v=spf1 ip4:203.0.113.0/24 -all")

    expect(section.findings).to be_empty
    expect(section.data).to eq(record: "v=spf1 ip4:203.0.113.0/24 -all", lookups: 0, all: "-all")
  end

  it "accepts ~all and ignores TXT records that are not SPF", :aggregate_failures do
    section = described_class.call(domain: "example.com", answer: answer("google-site-verification=abc", "v=spf1 mx ~all"))

    expect(section.findings).to be_empty
    expect(section.data).to include(lookups: 1, all: "~all")
  end

  it "reports a missing record, whether the domain has no TXT at all or only other TXT", :aggregate_failures do
    expect(keys(check([]))).to eq(%w[spf.missing])
    expect(check("hello").data).to be_nil
  end

  it "says so when the resolver could not answer" do
    section = described_class.call(domain: "example.com", answer: answer(status: :timeout))

    expect(section.findings).to eq([{ key: "spf.lookup_failed", tone: "warn", args: { name: "example.com" } }])
  end

  it "reports more than one record and analyses the first", :aggregate_failures do
    section = described_class.call(domain: "example.com", answer: answer("v=spf1 -all", "v=spf1 +all"))

    expect(keys(section)).to eq(%w[spf.multiple])
    expect(section.data[:record]).to eq("v=spf1 -all")
  end

  it "warns about a record that does not end with all, or ends with ?all or +all", :aggregate_failures do
    expect(keys(check("v=spf1 ip4:203.0.113.1"))).to eq(%w[spf.no_all])
    expect(keys(check("v=spf1 ip4:203.0.113.1 ?all"))).to eq(%w[spf.neutral_all])
    expect(keys(check("v=spf1 all"))).to eq(%w[spf.pass_all])
    expect(check("v=spf1 +all").findings.first[:tone]).to eq("bad")
  end

  it "warns about ptr" do
    expect(keys(check("v=spf1 ptr -all"))).to eq(%w[spf.ptr])
  end

  it "counts the lookups of includes, recursively, and ignores the all of an include", :aggregate_failures do
    section = check("v=spf1 include:a.example.net a mx -all", "a.example.net" => answer("v=spf1 include:b.example.net exists:%{i}.x.example.net +all"), "b.example.net" => answer("v=spf1 ip4:203.0.113.1 -all"))

    expect(section.data).to include(lookups: 5, all: "-all")
    expect(section.findings).to be_empty
  end

  it "reports a record that needs more than ten lookups" do
    section = check("v=spf1 #{Array.new(11) { |index| "include:i#{index}.example.net" }.join(" ")} -all", Array.new(11) { |index| ["i#{index}.example.net", answer("v=spf1 ip4:203.0.113.1 -all")] }.to_h)

    expect(section.findings).to eq([{ key: "spf.too_many_lookups", tone: "bad", args: { count: 11, limit: 10 } }])
  end

  it "does not ask about the includes of a record that is already far over the limit", :aggregate_failures do
    section = check("v=spf1 #{Array.new(25) { |index| "include:i#{index}.example.net" }.join(" ")} -all")

    expect(keys(section)).to eq(%w[spf.too_many_lookups])
    expect(Network::EmailChecks::Lookup).not_to have_received(:call)
  end

  it "stops following once a deeper record took it far over the limit", :aggregate_failures do
    section = check("v=spf1 include:a.example.net include:b.example.net -all", "a.example.net" => answer("v=spf1 #{(["a"] * 19).join(" ")} -all"), "b.example.net" => answer("v=spf1 -all"))

    expect(section.data[:lookups]).to eq(21)
    expect(keys(section)).to eq(%w[spf.too_many_lookups])
  end

  it "stops at the depth limit" do
    chain = Array.new(15) { |index| ["d#{index}.example.net", answer("v=spf1 include:d#{index + 1}.example.net -all")] }.to_h

    expect(check("v=spf1 include:d0.example.net -all", chain).data[:lookups]).to eq(described_class::MAX_DEPTH)
  end

  it "reports a loop", :aggregate_failures do
    section = check("v=spf1 include:a.example.net -all", "a.example.net" => answer("v=spf1 include:example.com -all"))

    expect(section.findings).to eq([{ key: "spf.loop", tone: "bad", args: { name: "example.com" } }])
  end

  it "reports an include with no SPF record or with a name that cannot be asked about", :aggregate_failures do
    missing = check("v=spf1 include:nothing.example.net include:bad_name!.example.net include:spf.example.net -all", "spf.example.net" => answer("hello"))

    expect(missing.findings.pluck(:args)).to eq([{ name: "nothing.example.net" }, { name: "bad_name!.example.net" }, { name: "spf.example.net" }])
    expect(keys(missing).uniq).to eq(%w[spf.include_missing])
  end

  it "warns when the resolver could not read an include" do
    section = check("v=spf1 include:slow.example.net -all", "slow.example.net" => answer(status: :timeout))

    expect(section.findings).to eq([{ key: "spf.lookup_failed", tone: "warn", args: { name: "slow.example.net" } }])
  end

  it "takes the end of the record from its redirect", :aggregate_failures do
    section = check("v=spf1 redirect=_spf.example.net", "_spf.example.net" => answer("v=spf1 ip4:203.0.113.1 -all"))

    expect(section.data).to include(lookups: 1, all: "-all")
    expect(section.findings).to be_empty
  end

  it "reads redirect and include targets with a trailing dot and a cidr, and skips macros and empty values", :aggregate_failures do
    section = check("v=spf1 a:mail.example.com/24 mx/24//64 include:%{d}.example.net include: redirect=_spf.example.net. ", "_spf.example.net" => answer("v=spf1 -all"))

    expect(section.data).to include(lookups: 5, all: "-all")
    expect(section.findings).to be_empty
  end

  it "keeps the include when its target is asked for several times", :aggregate_failures do
    section = check("v=spf1 include:a.example.net include:a.example.net -all", "a.example.net" => answer("v=spf1 -all"))

    expect(section.data[:lookups]).to eq(2)
    expect(Network::EmailChecks::Lookup).to have_received(:call).with("a.example.net", "TXT").once
  end
end
