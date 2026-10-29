require "rails_helper"

RSpec.describe Network::EmailChecks::Dkim do
  def answer(*records, status: records.empty? ? :nodata : :ok)
    Network::Dns::Query::Answer.new(status:, answers: records, ttl: 60, ms: 1)
  end

  def public_key(bits = 2048)
    Base64.strict_encode64(OpenSSL::PKey::RSA.new(bits).public_to_der)
  end

  def check(selectors, records)
    allow(Network::Dns::Lookup).to receive(:call) { |name, _type| records.fetch(name) { answer } }
    described_class.call(domain: "example.com", selectors:)
  end

  def keys(section)
    section.findings.pluck(:key)
  end

  it "reads the key of a typed selector", :aggregate_failures do
    section = check(%w[s1], "s1._domainkey.example.com" => answer("v=DKIM1; k=rsa; p=#{public_key}"))

    expect(section.findings).to be_empty
    expect(section.data).to eq(probed: false, rows: [{ selector: "s1", name: "s1._domainkey.example.com", status: "found", key_type: "rsa", bits: 2048, testing: false }])
  end

  it "reports a typed selector with no key", :aggregate_failures do
    section = check(%w[s1], {})

    expect(section.findings).to eq([{ key: "dkim.selector_missing", tone: "warn", args: { selector: "s1" } }])
    expect(section.data[:rows].first[:status]).to eq("missing")
  end

  it "does not take another kind of TXT record for a key" do
    expect(keys(check(%w[s1], "s1._domainkey.example.com" => answer("hello")))).to eq(%w[dkim.selector_missing])
  end

  it "says so when the resolver could not answer" do
    section = check(%w[s1], "s1._domainkey.example.com" => answer(status: :timeout))

    expect(section.findings).to eq([{ key: "dkim.lookup_failed", tone: "warn", args: { name: "s1._domainkey.example.com" } }])
  end

  it "reports a revoked key (empty p)" do
    expect(keys(check(%w[s1], "s1._domainkey.example.com" => answer("v=DKIM1; p=")))).to eq(%w[dkim.revoked])
  end

  it "reports a key that cannot be read, including one that is not RSA under k=rsa", :aggregate_failures do
    expect(keys(check(%w[s1], "s1._domainkey.example.com" => answer("v=DKIM1; p=bm90IGEga2V5")))).to eq(%w[dkim.invalid_key])
    ec = Base64.strict_encode64(OpenSSL::PKey::EC.generate("prime256v1").public_to_der)

    expect(keys(check(%w[s1], "s1._domainkey.example.com" => answer("v=DKIM1; k=rsa; p=#{ec}")))).to eq(%w[dkim.invalid_key])
  end

  it "warns about short keys and calls 512 bits an error", :aggregate_failures do
    expect(check(%w[s1], "s1._domainkey.example.com" => answer("p=#{public_key(1024)}")).findings).to eq([{ key: "dkim.weak_key", tone: "warn", args: { selector: "s1", bits: "1024" } }])
    expect(check(%w[s1], "s1._domainkey.example.com" => answer("p=#{public_key(512)}")).findings.first).to include(tone: "bad")
  end

  it "warns about a key in testing mode" do
    section = check(%w[s1], "s1._domainkey.example.com" => answer("v=DKIM1; t=y:s; p=#{public_key}"))

    expect(section.findings).to eq([{ key: "dkim.testing", tone: "warn", args: { selector: "s1" } }])
  end

  it "accepts keys that have no size to report", :aggregate_failures do
    section = check(%w[s1], "s1._domainkey.example.com" => answer("v=DKIM1; k=ed25519; p=11qYAYKxCrfVS/7TyWQHOg7hcvPapiMlrwIaaPcHURo="))

    expect(section.findings).to be_empty
    expect(section.data[:rows].first).to include(key_type: "ed25519", bits: 0)
  end

  it "tries the common selectors when none is typed and shows only the ones found", :aggregate_failures do
    section = check([], "google._domainkey.example.com" => answer("v=DKIM1; k=rsa; p=#{public_key}"), "k1._domainkey.example.com" => answer(status: :timeout))

    expect(section.data).to include(probed: true)
    expect(section.data[:rows].pluck(:selector)).to eq(%w[google])
    expect(section.findings).to be_empty
    expect(Network::Dns::Lookup).to have_received(:call).exactly(described_class::COMMON_SELECTORS.size).times
  end

  it "warns when none of the common selectors has a key" do
    section = check([], {})

    expect(section).to have_attributes(data: { probed: true, rows: [] }, findings: [{ key: "dkim.none_found", tone: "warn", args: {} }])
  end
end
