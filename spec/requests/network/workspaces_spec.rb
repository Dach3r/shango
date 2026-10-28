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

      expect(response.body).to include(I18n.t("network.ports.submit"), I18n.t("network.history.ports"), I18n.t("network.ports.presets.custom"))
      expect(response.body).not_to include(I18n.t("network.dns.submit"))

      get network_workspace_path("ping")

      expect(response.body).to include(I18n.t("network.ping.submit"))
    end

    it "opens reverse DNS as the DNS checker with PTR preselected", :aggregate_failures do
      sign_in_with_project
      get network_workspace_path("reverse_dns")

      expect(response.body).to include(I18n.t("network.dns.submit"), I18n.t("network.history.dns"), I18n.t("network.dns.ptr_placeholder"))
      expect(response.body).to include(%(value="PTR"))
      expect(response.body).to match(/<a(?=[^>]*aria-current="page")[^>]*href="#{network_workspace_path("reverse_dns")}"/)
    end

    it "has no page for an unknown tool" do
      sign_in_with_project

      get "/network/nmap"

      expect(response).to have_http_status(:not_found)
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

    it "is linked from the project tools" do
      sign_in_with_project
      get account_path, headers: { "Turbo-Frame" => "right_sidebar" }

      expect(response.body).to include(network_root_path)
    end
  end
end
