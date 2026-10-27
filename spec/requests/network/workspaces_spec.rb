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
      expect(response.body).to include(I18n.t("network.dns.submit"), I18n.t("network.tabs.ports"))
    end

    it "is linked from the project tools" do
      sign_in_with_project
      get account_path

      expect(response.body).to include(network_root_path)
    end
  end
end
