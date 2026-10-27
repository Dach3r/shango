require "rails_helper"

RSpec.describe "Network pings" do
  include_context "with workbench project"

  def attempt(status, ms = 12)
    Network::Tcp::Probe::Attempt.new(status:, ms:)
  end

  def create_ping(host: "example.com", port: "443", attempts: "3")
    post network_pings_path, params: { ping: { host:, port:, attempts: } }, headers: turbo_headers
    follow_redirect! if response.location.to_s.include?("/network/checks/")
  end

  before do
    allow(Network::Destination).to receive(:call).and_return(Result.success("203.0.113.9"))
    allow(Network::Tcp::Probe).to receive(:call).and_return(attempt(:open))
  end

  it "requires authentication" do
    sign_out user
    create_ping

    expect(response).to redirect_to(new_user_session_path)
  end

  it "saves the run and shows each attempt and the summary at its own address", :aggregate_failures do
    post network_pings_path, params: { ping: { host: "example.com", port: "443", attempts: "3" } }, headers: turbo_headers

    expect(response).to redirect_to(network_check_path(project.network_checks.last))
    follow_redirect!

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("ping_result", "203.0.113.9:443", "12 ms", I18n.t("network.statuses.open"))
    expect(response.body).to include(I18n.t("network.ping.summary", received: 3, sent: 3, loss: 0))
    expect(response.body).to include(I18n.t("network.results.min"), I18n.t("network.results.loss"))
    expect(project.network_checks.last).to have_attributes(target: "example.com", outcome: "ok")
  end

  it "says when only refusals came back", :aggregate_failures do
    allow(Network::Tcp::Probe).to receive(:call).and_return(attempt(:closed))
    create_ping

    expect(response.body).to include(I18n.t("network.ping.only_refused"))
    expect(project.network_checks.last.outcome).to eq("ok")
  end

  it "explains silence and early stops", :aggregate_failures do
    allow(Network::Tcp::Probe).to receive(:call).and_return(attempt(:filtered, 2000))
    create_ping(attempts: "10")

    expect(response.body).to include(I18n.t("network.ping.no_answer"), I18n.t("network.ping.stopped", count: 5))
    expect(response.body).not_to include("2000 ms")
    expect(project.network_checks.last.outcome).to eq("bad")
  end

  it "saves the run and reads port and attempts from variables", :aggregate_failures do
    environment = create(:environment, project:)
    create(:variable, environment:, key: "port", value: "8443")
    create(:variable, environment:, key: "tries", value: "2")
    membership.update!(current_environment: environment)

    expect { create_ping(port: "{{port}}", attempts: "{{tries}}") }.to change(project.network_checks.ping, :count).by(1)
    expect(project.network_checks.last.data).to include(port: 8443)
    expect(response.body).to include("203.0.113.9:8443")
  end

  it "still shows the result in place when the run cannot be saved", :aggregate_failures do
    allow(Network::Checks::Record).to receive(:call).and_return(Result.failure(error: :not_saved))
    create_ping

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include("ping_result")
  end

  it "answers 422 with the error for invalid input", :aggregate_failures do
    create_ping(port: "0")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t("network.errors.invalid_port"))
  end

  it "answers 422 for too many attempts", :aggregate_failures do
    create_ping(attempts: "50")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t("network.errors.invalid_attempts", max: 10))
  end

  describe "throttling" do
    before do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      stub_const("ENV", ENV.to_h.merge("SHANGO_RATE_LIMIT_NETWORK" => "1/60"))
    end

    it "answers into the ping result area once the limit is hit", :aggregate_failures do
      2.times { create_ping }

      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include("ping_result", I18n.t("throttling.limited"))
    end
  end

  it "logs who pinged which host and port" do
    allow(Rails.logger).to receive(:info)
    create_ping

    expect(Rails.logger).to have_received(:info).with(a_string_matching(/\[network\] ping user=#{user.id} project=#{project.id} input="example.com" outcome=ok host=example.com port=443/))
  end
end
