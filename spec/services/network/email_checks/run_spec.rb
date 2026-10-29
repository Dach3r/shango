require "rails_helper"

RSpec.describe Network::EmailChecks::Run do
  def answer(*records, status: records.empty? ? :nodata : :ok)
    Network::Dns::Query::Answer.new(status:, answers: records, ttl: 60, ms: 1)
  end

  def run(domain: "Example.com", **options)
    described_class.call(domain:, **options)
  end

  before do
    allow(Network::EmailChecks::Lookup).to receive(:call) do |name, type|
      {
        ["example.com", "TXT"] => answer("v=spf1 ip4:203.0.113.1 -all"),
        ["_dmarc.example.com", "TXT"] => answer("v=DMARC1; p=none"),
        ["example.com", "MX"] => answer("10 mx.example.com"),
        ["mx.example.com", "A"] => answer("203.0.113.5")
      }.fetch([name, type]) { answer }
    end
  end

  it "checks SPF, DKIM, DMARC and MX of the domain", :aggregate_failures do
    result = run

    expect(result).to be_success
    expect(result.data).to include(host: "example.com")
    expect(result.data[:spf]).to include(all: "-all")
    expect(result.data[:dkim]).to include(probed: true)
    expect(result.data[:dmarc]).to include(policy: "none")
    expect(result.data[:mx][:records]).to eq([{ preference: 10, exchange: "mx.example.com", status: "ok" }])
  end

  it "lists what breaks mail before what should be fixed", :aggregate_failures do
    allow(Network::EmailChecks::Lookup).to receive(:call) { |_name, _type| answer }
    result = run

    expect(result.data[:findings].pluck(:key)).to eq(%w[spf.missing dmarc.missing dkim.none_found mx.missing])
    expect(result.data[:findings].pluck(:tone)).to eq(%w[bad bad warn warn])
  end

  it "checks the selectors typed after the domain, in lowercase and without repeats", :aggregate_failures do
    result = run(selectors: " Selector1 selector1 s2.eu ")

    expect(result.data[:dkim]).to include(probed: false)
    expect(result.data[:dkim][:rows].pluck(:selector)).to eq(%w[selector1 s2.eu])
  end

  it "reads variables in the domain and the selectors" do
    environment = create(:environment)
    create(:variable, environment:, key: "domain", value: "example.com")
    create(:variable, environment:, key: "selector", value: "k1")
    result = run(domain: "{{domain}}", selectors: "{{selector}}", environment:)

    expect(result.data).to include(host: "example.com")
    expect(result.data[:dkim][:rows].pluck(:selector)).to eq(%w[k1])
  end

  it "refuses an IP address" do
    expect(run(domain: "203.0.113.9")).to have_attributes(failure?: true, error: :domain_needed)
  end

  it "refuses a domain that does not exist" do
    allow(Network::EmailChecks::Lookup).to receive(:call).with("example.com", "TXT").and_return(answer(status: :nxdomain))

    expect(run).to have_attributes(failure?: true, error: :domain_not_found)
  end

  it "refuses an invalid target and an undefined selector variable", :aggregate_failures do
    expect(run(domain: "bad domain!")).to have_attributes(failure?: true, error: :invalid)
    expect(run(selectors: "{{nope}}")).to have_attributes(failure?: true, error: :unresolved_variable)
  end

  it "refuses invalid selectors and too many of them", :aggregate_failures do
    expect(run(selectors: "ok bad!name")).to have_attributes(failure?: true, error: :invalid_selector, data: { token: "bad!name" })
    expect(run(selectors: Array.new(11) { |index| "s#{index}" }.join(" "))).to have_attributes(failure?: true, error: :too_many_selectors, data: { max: described_class::MAX_SELECTORS })
  end
end
