require "rails_helper"

RSpec.describe Network::EmailChecks::Dmarc do
  def answer(*records, status: records.empty? ? :nodata : :ok)
    Network::Dns::Query::Answer.new(status:, answers: records, ttl: 60, ms: 1)
  end

  def check(records, domain = "example.com")
    allow(Network::EmailChecks::Lookup).to receive(:call) { |name, _type| records.fetch(name) { answer } }
    described_class.call(domain:)
  end

  def keys(section)
    section.findings.pluck(:key)
  end

  it "reads a complete policy", :aggregate_failures do
    section = check("_dmarc.example.com" => answer("v=DMARC1; p=reject; sp=reject; pct=100; rua=mailto:a@example.com, mailto:b@example.com"))

    expect(section.findings).to be_empty
    expect(section.data).to eq(record: "v=DMARC1; p=reject; sp=reject; pct=100; rua=mailto:a@example.com, mailto:b@example.com", domain: "example.com", policy: "reject",
                               subdomain_policy: "reject", pct: "100", rua: %w[mailto:a@example.com mailto:b@example.com])
  end

  it "reports a missing record" do
    section = check({})

    expect(section).to have_attributes(data: nil, findings: [{ key: "dmarc.missing", tone: "bad", args: {} }])
  end

  it "says so when the resolver could not answer instead of calling the record missing" do
    section = check("_dmarc.example.com" => answer(status: :timeout))

    expect(section.findings).to eq([{ key: "dmarc.lookup_failed", tone: "warn", args: { name: "_dmarc.example.com" } }])
  end

  it "ignores TXT records that are not DMARC" do
    expect(keys(check("_dmarc.example.com" => answer("hello")))).to eq(%w[dmarc.missing])
  end

  it "reports more than one record" do
    expect(keys(check("_dmarc.example.com" => answer("v=DMARC1; p=reject; rua=mailto:a@example.com", "v=DMARC1; p=none")))).to eq(%w[dmarc.multiple])
  end

  it "uses the record of the parent domain and says where it was found", :aggregate_failures do
    section = check({ "_dmarc.example.com" => answer("v=DMARC1; p=reject; rua=mailto:a@example.com") }, "mail.eu.example.com")

    expect(section.data).to include(domain: "example.com", policy: "reject")
    expect(section.findings).to be_empty
  end

  it "prefers the record of the domain itself over its parent's" do
    section = check({ "_dmarc.mail.example.com" => answer("v=DMARC1; p=quarantine; rua=mailto:a@example.com"), "_dmarc.example.com" => answer("v=DMARC1; p=reject") }, "mail.example.com")

    expect(section.data).to include(domain: "mail.example.com", policy: "quarantine")
  end

  it "reports a policy that is missing or invalid", :aggregate_failures do
    expect(keys(check("_dmarc.example.com" => answer("v=DMARC1; rua=mailto:a@example.com")))).to eq(%w[dmarc.invalid_policy])
    expect(keys(check("_dmarc.example.com" => answer("v=DMARC1; p=block; rua=mailto:a@example.com")))).to eq(%w[dmarc.invalid_policy])
  end

  it "warns when the policy only monitors, and about missing reports", :aggregate_failures do
    section = check("_dmarc.example.com" => answer("v=DMARC1; p=none"))

    expect(keys(section)).to eq(%w[dmarc.policy_none dmarc.no_reports])
    expect(section.data).to include(policy: "none", subdomain_policy: nil, pct: nil, rua: [])
  end

  it "warns about a subdomain policy weaker than the policy", :aggregate_failures do
    section = check("_dmarc.example.com" => answer("v=DMARC1; p=reject; sp=none; rua=mailto:a@example.com"))

    expect(section.findings).to eq([{ key: "dmarc.weak_subdomain_policy", tone: "warn", args: { sp: "none", p: "reject" } }])
    expect(keys(check("_dmarc.example.com" => answer("v=DMARC1; p=quarantine; sp=reject; rua=mailto:a@example.com")))).to be_empty
    expect(keys(check("_dmarc.example.com" => answer("v=DMARC1; p=reject; sp=oops; rua=mailto:a@example.com")))).to be_empty
  end

  it "warns when only part of the failing mail gets the policy", :aggregate_failures do
    expect(check("_dmarc.example.com" => answer("v=DMARC1; p=reject; pct=25; rua=mailto:a@example.com")).findings).to eq([{ key: "dmarc.partial", tone: "warn", args: { pct: "25" } }])
    expect(keys(check("_dmarc.example.com" => answer("v=DMARC1; p=none; pct=25; rua=mailto:a@example.com")))).to eq(%w[dmarc.policy_none])
    expect(keys(check("_dmarc.example.com" => answer("v=DMARC1; p=reject; pct=lots; rua=mailto:a@example.com")))).to be_empty
  end
end
