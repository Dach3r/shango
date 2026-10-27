require "rails_helper"

RSpec.describe "Network DNS checks" do
  include_context "with workbench project"

  let(:resolver) { Network::Dns::Resolvers::Resolver.new(name: "Google", ip: "8.8.8.8", group: :public) }

  def answer(status = :ok, *answers)
    Network::Dns::Query::Answer.new(status:, answers:, ttl: 60, ms: 12)
  end

  def create_check(domain: "example.com", type: "A", expected: "")
    post network_dns_checks_path, params: { dns_check: { domain:, type:, expected: } }, headers: turbo_headers
  end

  before do
    allow(Network::Dns::Resolvers).to receive(:authoritative).and_return([Network::Dns::Resolvers::Resolver.new(name: "ns1.example.net", ip: "192.0.2.1", group: :authoritative)])
    stub_const("Network::Dns::Resolvers::PUBLIC", [resolver])
    allow(Network::Dns::Query).to receive(:call).and_return(answer(:ok, "203.0.113.10"))
  end

  it "requires authentication" do
    sign_out user
    create_check

    expect(response).to redirect_to(new_user_session_path)
  end

  it "renders the propagation table as a Turbo Stream", :aggregate_failures do
    create_check(expected: "203.0.113.10")

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include("dns_result", "ns1.example.net", "Google", "203.0.113.10", I18n.t("network.dns.groups.authoritative"))
    expect(response.body).to include(I18n.t("network.dns.summary.expected", matched: 2, total: 2))
  end

  it "shows rows that did not answer and a note when the nameservers are unknown", :aggregate_failures do
    allow(Network::Dns::Resolvers).to receive(:authoritative).and_return([])
    allow(Network::Dns::Query).to receive(:call).and_return(answer(:timeout))
    create_check

    expect(response.body).to include(I18n.t("network.statuses.timeout"), I18n.t("network.dns.no_authoritative"))
    expect(response.body).not_to include(I18n.t("network.dns.summary.agree"))
  end

  it "shows alias answers and differing results", :aggregate_failures do
    allow(Network::Dns::Query).to receive(:call).and_return(answer(:cname, "target.example.net"), answer(:ok, "203.0.113.10"))
    create_check

    expect(response.body).to include("→ target.example.net", I18n.t("network.dns.summary.differ"))
  end

  it "resolves variables from the selected environment", :aggregate_failures do
    environment = create(:environment, project:)
    create(:variable, environment:, key: "host", value: "api.example.com")
    membership.update!(current_environment: environment)
    create_check(domain: "{{host}}")

    expect(response.body).to include("api.example.com")
  end

  it "answers 422 with the error for invalid input", :aggregate_failures do
    create_check(domain: "https://example.com")

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include(CGI.escapeHTML(I18n.t("network.errors.invalid")))
  end

  it "names the variable that is not defined", :aggregate_failures do
    create_check(domain: "{{nope}}")

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("{{nope}}")
  end

  it "answers 422 for an unsupported type" do
    create_check(type: "ANY")

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "rejects a request without the form fields" do
    post network_dns_checks_path, headers: turbo_headers

    expect(response).to have_http_status(:bad_request)
  end

  describe "throttling" do
    before do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      stub_const("ENV", ENV.to_h.merge("SHANGO_RATE_LIMIT_NETWORK" => "2/60"))
    end

    it "limits runs per user", :aggregate_failures do
      2.times { create_check }
      create_check

      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include("dns_result", I18n.t("throttling.limited"))
      expect(response.headers["Retry-After"]).to eq("60")
    end
  end
end
