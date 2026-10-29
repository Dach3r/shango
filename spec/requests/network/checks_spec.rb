require "rails_helper"

RSpec.describe "Network checks" do
  include_context "with workbench project"

  let!(:check) { create(:network_check, project:, user:, input: { "domain" => "shango.dev", "type" => "TXT", "expected" => "v=spf1" }) }

  describe "GET /network/checks/:id" do
    it "requires authentication" do
      sign_out user
      get network_check_path(check)

      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows the tool with the stored result, the typed values and the entry marked", :aggregate_failures do
      get network_check_path(check)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("dns_result", "shango.dev", "v=spf1", "203.0.113.10")
      expect(response.body).to include('aria-current="true"', 'aria-current="page"')
      expect(response.body).not_to include(I18n.t("network.ports.submit"))
    end

    it "keeps the bar editable with what was typed, so submitting records a new run", :aggregate_failures do
      get network_check_path(check)

      expect(response.body).to include(%(action="#{network_dns_checks_path}"), I18n.t("network.dns.submit"), 'value="shango.dev v=spf1"')
      expect(response.body).not_to include("readonly")
    end

    it "mentions the previous run of the same target", :aggregate_failures do
      earlier = create(:network_check, project:, user:, created_at: 2.hours.ago)
      later = create(:network_check, project:, user:, created_at: 1.hour.ago)
      get network_check_path(later)

      expect(earlier.created_at).to be < later.created_at
      expect(response.body).to include(CGI.escapeHTML(I18n.t("network.history.previous", time: "about 2 hours", detail: I18n.t("network.dns.summary.answered", answered: 1, total: 1))))
    end

    it "shows a saved reverse DNS run in the DNS tool with the IP placeholder" do
      reverse = create(:network_check, project:, user:, target: "8.8.8.8", input: { "domain" => "8.8.8.8", "type" => "PTR" })
      get network_check_path(reverse)

      expect(response.body).to include(%(placeholder="#{I18n.t("network.dns.ptr_placeholder")}"))
    end

    it "shows a saved subnet with what was typed, ready to run again", :aggregate_failures do
      subnet = create(:network_check, :subnet, project:, user:)
      get network_check_path(subnet)

      expect(response.body).to include("subnet_result", "192.168.1.0/24", "192.168.1.10/24", "192.168.1.77", I18n.t("network.statuses.inside"), I18n.t("network.subnet.submit"))
      expect(response.body).to include(I18n.t("network.subnet.summary", version: 4, hosts: 254))
    end

    it "shows a saved TLS check with what was typed, ready to run again", :aggregate_failures do
      tls = create(:network_check, :tls, project:, user:, input: { "host" => "example.com", "port" => "", "protocol" => "smtp" })
      get network_check_path(tls)

      expect(response.body).to include("tls_result", "Shango Test Root", "www.example.com", "AB:CD:EF", I18n.t("network.tls.no_findings"), I18n.t("network.statuses.trusted"))
      expect(response.body).to include(%(action="#{network_tls_checks_path}"), 'value="example.com"', 'placeholder="587"')
      expect(response.body).to include(I18n.t("network.tls.summary.valid", date: "2026-11-30", version: "TLSv1.3"))
    end

    it "shows a saved email check with what was typed, ready to run again", :aggregate_failures do
      email = create(:network_check, :email, project:, user:)
      get network_check_path(email)

      expect(response.body).to include("email_result", "v=spf1 include:_spf.example.net -all", "selector1._domainkey.example.com", "mx.example.com", I18n.t("network.statuses.healthy"))
      expect(response.body).to include(%(action="#{network_email_checks_path}"), 'value="example.com selector1"')
      expect(response.body).to include(I18n.t("network.email.summary.clean"))
    end

    it "shows saved port checks and pings in their own tool", :aggregate_failures do
      ports = create(:network_check, :ports, project:, user:)
      get network_check_path(ports)

      expect(response.body).to include("ports_result", I18n.t("network.ports.columns.service"), I18n.t("network.ports.submit"))

      ping = create(:network_check, :ping, project:, user:)
      get network_check_path(ping)

      expect(response.body).to include("ping_result", "443", I18n.t("network.ping.submit"))
    end

    it "does not show runs of other projects" do
      get network_check_path(create(:network_check))

      expect(response).to have_http_status(:not_found)
    end

    it "does not show runs of other members of the project" do
      get network_check_path(create(:network_check, project:))

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /network/checks/:id" do
    it "deletes the run and goes back to the tool", :aggregate_failures do
      expect { delete network_check_path(check) }.to change(NetworkCheck, :count).by(-1)
      expect(response).to redirect_to(network_workspace_path("dns"))
    end

    it "does not delete runs of other members of the project", :aggregate_failures do
      teammate = create(:network_check, project:)

      expect { delete network_check_path(teammate) }.not_to change(NetworkCheck, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "does not delete runs of other projects", :aggregate_failures do
      foreign = create(:network_check)

      expect { delete network_check_path(foreign) }.not_to change(NetworkCheck, :count)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /network/history" do
    it "clears only the user's history of one tool in the project", :aggregate_failures do
      ports = create(:network_check, :ports, project:, user:)
      foreign = create(:network_check)
      teammate = create(:network_check, project:)
      delete network_history_path(kind: "dns")

      expect(NetworkCheck.where(id: [check.id, foreign.id, ports.id, teammate.id])).to contain_exactly(foreign, ports, teammate)
      expect(response).to redirect_to(network_workspace_path("dns"))
    end

    it "rejects unknown tools", :aggregate_failures do
      delete network_history_path(kind: "icmp")

      expect(response).to have_http_status(:unprocessable_content)
      expect(NetworkCheck.count).to eq(1)
    end
  end
end
