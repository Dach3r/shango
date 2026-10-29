require "rails_helper"

RSpec.describe "Network lookups" do
  include_context "with workbench project"

  let(:domain_json) do
    {
      "ldhName" => "EXAMPLE.COM", "status" => ["client transfer prohibited"], "secureDNS" => { "delegationSigned" => false },
      "events" => [{ "eventAction" => "registration", "eventDate" => "1995-08-14T04:00:00Z" }, { "eventAction" => "expiration", "eventDate" => 400.days.from_now.utc.iso8601 }],
      "nameservers" => [{ "ldhName" => "A.IANA-SERVERS.NET" }],
      "entities" => [{ "roles" => ["registrar"], "vcardArray" => ["vcard", [["fn", {}, "text", "RESERVED-IANA"]]], "entities" => [{ "roles" => ["abuse"], "vcardArray" => ["vcard", [["email", {}, "text", "abuse@iana.example"]]] }] }]
    }
  end
  let(:address_json) do
    { "name" => "GOGL", "handle" => "NET-8", "startAddress" => "8.8.8.0", "endAddress" => "8.8.8.255", "cidr0_cidrs" => [{ "v4prefix" => "8.8.8.0", "length" => 24 }],
      "entities" => [{ "roles" => ["registrant"], "vcardArray" => ["vcard", [["fn", {}, "text", "Google LLC"], ["kind", {}, "text", "org"]]] }] }
  end

  def create_lookup(host: "example.com")
    post network_lookups_path, params: { lookup: { host: } }, headers: turbo_headers
    follow_redirect! if response.location.to_s.include?("/network/checks/")
  end

  before do
    allow(Network::Rdap::Bootstrap).to receive(:call).and_return(Result.success("https://rdap.example.net/"))
    allow(Network::Rdap::Client).to receive(:call) { |url:, **| Result.success(url.include?("/ip/") ? address_json : domain_json) }
    allow(Network::Dns::Lookup).to receive(:call) do |name, _type|
      text = name.start_with?("AS") ? "15169 | US | arin | 2000-03-30 | GOOGLE, US" : "15169 | 8.8.8.0/24 | US | arin | 2023-12-28"
      Network::Dns::Query::Answer.new(status: :ok, answers: [text], ttl: 60, ms: 1)
    end
  end

  it "requires authentication" do
    sign_out user
    create_lookup

    expect(response).to redirect_to(new_user_session_path)
  end

  it "saves the run and shows the domain at its own address", :aggregate_failures do
    post network_lookups_path, params: { lookup: { host: "example.com" } }, headers: turbo_headers

    expect(response).to redirect_to(network_check_path(project.network_checks.last))
    follow_redirect!

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("lookup_result", "RESERVED-IANA", "abuse@iana.example", "a.iana-servers.net", "client transfer prohibited", I18n.t("network.lookup.no_findings"))
    expect(response.body).to include(I18n.t("network.statuses.unsigned"), I18n.t("network.statuses.valid"))
    expect(project.network_checks.last).to have_attributes(kind: "lookup", target: "example.com", outcome: "ok", input: { "host" => "example.com" })
  end

  it "names the registered domain when a subdomain was typed" do
    allow(Network::Rdap::Client).to receive(:call) { |url:, **| url.end_with?("www.example.com") ? Result.failure(error: :not_found) : Result.success(domain_json) }
    create_lookup(host: "www.example.com")

    expect(response.body).to include(I18n.t("network.lookup.registered_domain", name: "example.com"))
  end

  it "shows an IP address with its network and autonomous system", :aggregate_failures do
    create_lookup(host: "8.8.8.8")

    expect(response.body).to include("AS15169", "GOOGLE, US", "Google LLC", "8.8.8.0 - 8.8.8.255", "8.8.8.0/24", I18n.t("network.lookup.asn_title"))
    expect(project.network_checks.last).to have_attributes(target: "8.8.8.8", outcome: "ok")
  end

  it "shows what is wrong and keeps the run as bad", :aggregate_failures do
    domain_json["status"] = ["client hold"]
    create_lookup

    expect(response.body).to include(I18n.t("network.lookup.findings.hold"))
    expect(project.network_checks.last.outcome).to eq("bad")
  end

  it "reads variables in the host", :aggregate_failures do
    environment = create(:environment, project:)
    create(:variable, environment:, key: "site", value: "example.com")
    membership.update!(current_environment: environment)
    create_lookup(host: "{{site}}")

    expect(response.body).to include("RESERVED-IANA")
    expect(project.network_checks.last.input).to eq("host" => "{{site}}")
  end

  it "still shows the result in place when the run cannot be saved", :aggregate_failures do
    allow(Network::Checks::Record).to receive(:call).and_return(Result.failure(error: :not_saved))
    create_lookup

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include("lookup_result")
  end

  it "answers 422 with the reason for a domain that is not registered or an address that is private", :aggregate_failures do
    allow(Network::Rdap::Client).to receive(:call).and_return(Result.failure(error: :not_found))

    expect { create_lookup }.not_to change(NetworkCheck, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t("network.errors.not_registered"))

    create_lookup(host: "10.0.0.1")

    expect(response.body).to include(I18n.t("network.errors.private_address"))
  end

  describe "throttling" do
    before do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      stub_const("ENV", ENV.to_h.merge("SHANGO_RATE_LIMIT_NETWORK" => "1/60"))
    end

    it "answers into the lookup result area once the limit is hit", :aggregate_failures do
      2.times { create_lookup }

      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include("lookup_result", I18n.t("throttling.limited"))
    end
  end

  it "logs who looked up what" do
    allow(Rails.logger).to receive(:info)
    create_lookup

    expect(Rails.logger).to have_received(:info).with(a_string_matching(/\[network\] lookup user=#{user.id} project=#{project.id} input="example.com" outcome=ok host=example.com type=domain/))
  end
end
