require "rails_helper"

RSpec.describe "Network subnets" do
  include_context "with workbench project"

  def calculate(**fields)
    post network_subnets_path, params: { subnet: { network: "192.168.1.0/24", **fields } }, headers: turbo_headers
  end

  it "requires authentication" do
    sign_out user
    calculate

    expect(response).to redirect_to(new_user_session_path)
  end

  it "shows the range of the network without saving it", :aggregate_failures do
    expect { calculate }.not_to change(NetworkCheck, :count)

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
    post network_subnets_path, params: { subnet: { network: "2001:db8::/48", split: "/64" } }, headers: turbo_headers

    expect(response.body).to include("2^80", I18n.t("network.subnet.split_truncated", shown: 64, count: "65,536"))
    expect(response.body).not_to include(I18n.t("network.subnet.fields.broadcast"))
  end

  it "answers 422 with the error for invalid input", :aggregate_failures do
    calculate(split: "/8")

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
