require "rails_helper"

RSpec.describe "Network workspace" do
  describe "GET /network" do
    it "requires authentication" do
      get network_root_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders the tools", :aggregate_failures do
      sign_in_with_project
      get network_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("network.dns.submit"), I18n.t("network.ports.submit"), I18n.t("network.ping.submit"))
      expect(response.body).to include(I18n.t("network.history.dns"), I18n.t("network.history.ports"), I18n.t("network.history.ping"))
    end

    it "shows the ping limits", :aggregate_failures do
      sign_in_with_project
      get network_root_path

      count, window = Throttling.limit(:network)
      expect(response.body).to include(I18n.t("network.limits.rate_value", count:, seconds: window.to_i))
      expect(response.body).to include("1–#{Network::Pings::Run::MAX_ATTEMPTS}")
    end

    it "is linked from the project tools" do
      sign_in_with_project
      get account_path

      expect(response.body).to include(network_root_path)
    end
  end
end
