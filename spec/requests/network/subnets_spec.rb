require "rails_helper"

RSpec.describe "Network subnets" do
  include_context "with workbench project"

  def calculate(network: "192.168.1.0/24", **fields)
    post network_subnets_path, params: { subnet: { network:, **fields } }, headers: turbo_headers
    follow_redirect! if response.location.to_s.include?("/network/checks/")
  end

  it "requires authentication" do
    sign_out user
    calculate

    expect(response).to redirect_to(new_user_session_path)
  end

  it "saves the run and shows the range of the network at its own address", :aggregate_failures do
    expect { calculate(contains: "") }.to change(project.network_checks.subnet, :count).by(1)

    expect(request.path).to eq(network_check_path(project.network_checks.last))
    expect(project.network_checks.last).to have_attributes(target: "192.168.1.0/24", outcome: "ok", input: { "network" => "192.168.1.0/24" })
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("subnet_result", "192.168.1.0/24", "255.255.255.0", "0.0.0.255", "192.168.1.255", "254")
    expect(response.body).to include(I18n.t("network.subnet.fields.broadcast"), I18n.t("network.subnet.scopes.private"), "IPv4")
    expect(response.body).not_to include(I18n.t("network.subnet.contains_title"))
  end

  it "shows the split and whether the address is inside", :aggregate_failures do
    calculate(split: "/26", contains: "192.168.1.77")

    expect(response.body).to include(I18n.t("network.subnet.split_title", count: 4, prefix: 26), "192.168.1.192/26", I18n.t("network.statuses.inside"))
    expect(response.body).not_to include(I18n.t("network.subnet.split_truncated", shown: 64, count: 4))

    calculate(contains: "10.0.0.1")

    expect(response.body).to include(I18n.t("network.statuses.outside"))
  end

  it "writes large counts as powers of two and notes a cut list", :aggregate_failures do
    calculate(network: "2001:db8::/48", split: "/64")

    expect(response.body).to include("2^80", I18n.t("network.subnet.split_truncated", shown: 64, count: "65,536"))
    expect(response.body).not_to include(I18n.t("network.subnet.fields.broadcast"))
  end

  it "marks the run when the address is outside", :aggregate_failures do
    calculate(contains: "10.0.0.1")

    expect(project.network_checks.last.outcome).to eq("warn")
    expect(response.body).to include(I18n.t("network.history.subnet"), "192.168.1.0/24")
  end

  it "answers 422 with the error for invalid input and saves nothing", :aggregate_failures do
    expect { calculate(split: "/8") }.not_to change(NetworkCheck, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t("network.errors.invalid_split", min: 25, max: 32))
  end

  it "rejects a request without the form fields" do
    post network_subnets_path, headers: turbo_headers

    expect(response).to have_http_status(:bad_request)
  end

  describe "throttling" do
    before do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      stub_const("ENV", ENV.to_h.merge("SHANGO_RATE_LIMIT_NETWORK" => "1/60"))
    end

    it "shares the network rate limit", :aggregate_failures do
      2.times { calculate }

      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include("subnet_result", I18n.t("throttling.limited"))
    end
  end
end
