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

    it "switches the domain placeholder to an IP address when PTR is chosen", :aggregate_failures do
      sign_in_with_project
      get network_root_path

      expect(response.body).to include('data-controller="dns-type variable-autocomplete"', 'data-dns-type-target="type"', 'data-dns-type-target="field"')
      expect(response.body).to include(%(data-dns-type-ptr-value="#{I18n.t("network.dns.ptr_placeholder")}"), %(placeholder="#{I18n.t("network.dns.domain_placeholder")}"))
    end

    it "renders the subnet calculator with its history", :aggregate_failures do
      sign_in_with_project
      get network_workspace_path("subnet")

      expect(response.body).to include(I18n.t("network.subnet.submit"), network_subnets_path, I18n.t("network.empty.subnet.hint"), I18n.t("network.groups.utilities"))
      expect(response.body).to include(I18n.t("network.history.subnet"), I18n.t("network.history.empty"))
    end

    it "renders the TLS check with the usual port of the protocol as placeholder", :aggregate_failures do
      sign_in_with_project
      get network_workspace_path("tls")

      expect(response.body).to include(I18n.t("network.tls.submit"), network_tls_checks_path, I18n.t("network.empty.tls.hint"), I18n.t("network.groups.security"), I18n.t("network.history.tls"))
      expect(response.body).to include('data-controller="tls-protocol variable-autocomplete"', 'data-tls-protocol-target="port"', 'placeholder="443"', I18n.t("network.tls.protocols.smtp"))
    end

    it "renders the email DNS check", :aggregate_failures do
      sign_in_with_project
      get network_workspace_path("email")

      expect(response.body).to include(I18n.t("network.email.submit"), network_email_checks_path, I18n.t("network.empty.email.hint"), I18n.t("network.history.email"), I18n.t("network.tabs.email"))
      expect(response.body).to include('data-controller="variable-autocomplete"', I18n.t("network.statuses.healthy"), I18n.t("network.guide.missing"))
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
