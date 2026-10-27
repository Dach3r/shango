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
      expect(response.body).to include(I18n.t("network.dns.submit"), I18n.t("network.history.dns"))
      expect(response.body).to include(network_workspace_path("ports"), network_workspace_path("ping"))
      expect(response.body).not_to include(I18n.t("network.ports.submit"))
    end

    it "renders one page per tool", :aggregate_failures do
      sign_in_with_project
      get network_workspace_path("ports")

      expect(response.body).to include(I18n.t("network.ports.submit"), I18n.t("network.history.ports"))
      expect(response.body).not_to include(I18n.t("network.dns.submit"))

      get network_workspace_path("ping")

      expect(response.body).to include(I18n.t("network.ping.submit"))
    end

    it "lists the saved runs of the project, newest first, and not those of other projects", :aggregate_failures do
      user, project = sign_in_with_project
      create(:network_check, project:, user:, target: "shango.dev", result: build(:network_check).result.merge("host" => "shango.dev"))
      create(:network_check, result: build(:network_check).result.merge("host" => "foreign.dev"))
      get network_root_path

      expect(response.body).to include("shango.dev · A")
      expect(response.body).not_to include("foreign.dev")
    end

    it "offers variable autocomplete on the forms", :aggregate_failures do
      _user, project, membership = sign_in_with_project
      environment = create(:environment, project:)
      create(:variable, environment:, key: "host", value: "api.example.com")
      membership.update!(current_environment: environment)
      get network_root_path

      expect(response.body).to include("variable-autocomplete", "host")
    end

    it "shows the ping limits", :aggregate_failures do
      sign_in_with_project
      get network_workspace_path("ping")

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
