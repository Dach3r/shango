require "rails_helper"

RSpec.describe "Network port checks" do
  include_context "with workbench project"

  def attempt(status)
    Network::Tcp::Probe::Attempt.new(status:, ms: 7)
  end

  def create_check(host: "example.com", ports: "22, 80")
    post network_port_checks_path, params: { port_check: { host:, ports: } }, headers: turbo_headers
  end

  before do
    allow(Network::Destination).to receive(:call).and_return(Result.success("203.0.113.9"))
    allow(Network::Tcp::Probe).to receive(:call) { |port:, **| attempt(port == 22 ? :open : :closed) }
  end

  it "requires authentication" do
    sign_out user
    create_check

    expect(response).to redirect_to(new_user_session_path)
  end

  it "renders the port table as a Turbo Stream", :aggregate_failures do
    create_check

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include("ports_result", "203.0.113.9", "ssh", I18n.t("network.statuses.open"), I18n.t("network.statuses.closed"), "7 ms")
    expect(response.body).to include(I18n.t("network.ports.summary", open: 1, closed: 1, filtered: 0))
  end

  it "explains when nothing answered", :aggregate_failures do
    allow(Network::Tcp::Probe).to receive(:call).and_return(attempt(:filtered))
    create_check

    expect(response.body).to include(I18n.t("network.ports.all_filtered"))
    expect(response.body).not_to include("7 ms")
  end

  it "answers 422 with the error for invalid ports", :aggregate_failures do
    create_check(ports: "abc")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(CGI.escapeHTML(I18n.t("network.errors.invalid_ports", token: "abc")))
  end

  it "answers 422 when the guard blocks the host", :aggregate_failures do
    allow(Network::Destination).to receive(:call).and_return(Result.failure(error: :blocked, detail: "internal resolves to a private address (10.0.0.1)"))
    create_check(host: "internal")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("10.0.0.1")
  end

  it "logs who checked which host", :aggregate_failures do
    allow(Rails.logger).to receive(:info)
    create_check

    expect(Rails.logger).to have_received(:info).with(a_string_matching(/\[network\] port_check user=#{user.id} project=#{project.id} input="example.com" outcome=ok host=example.com ports=2/))
  end

  it "logs refused runs with the reason" do
    allow(Rails.logger).to receive(:info)
    create_check(ports: "abc")

    expect(Rails.logger).to have_received(:info).with(a_string_matching(/outcome=invalid_ports/))
  end

  it "escapes control characters in the logged input" do
    allow(Rails.logger).to receive(:info)
    create_check(host: "bad\nhost")

    expect(Rails.logger).to have_received(:info).with(a_string_matching(/input="bad\\nhost"/))
  end

  describe "throttling" do
    before do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      stub_const("ENV", ENV.to_h.merge("SHANGO_RATE_LIMIT_NETWORK" => "1/60"))
    end

    it "shares the limit across tools and answers into the tool's result area", :aggregate_failures do
      allow(Network::DnsChecks::Run).to receive(:call).and_return(Result.failure(error: :invalid))
      post network_dns_checks_path, params: { dns_check: { domain: "example.com", type: "A" } }, headers: turbo_headers
      create_check

      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include("ports_result", I18n.t("throttling.limited"))
    end
  end
end
