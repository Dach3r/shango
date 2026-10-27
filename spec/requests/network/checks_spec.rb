require "rails_helper"

RSpec.describe "Network checks" do
  include_context "with workbench project"

  let!(:check) { create(:network_check, project:, user:, input: { "domain" => "shango.dev", "type" => "TXT", "expected" => "v=spf1" }) }

  describe "GET /network/checks/:id" do
    it "requires authentication" do
      sign_out user
      get network_check_path(check), headers: turbo_headers

      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows the stored result, refills the form and marks the entry", :aggregate_failures do
      get network_check_path(check), headers: turbo_headers

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("dns_result", "dns_form", "dns_history", "shango.dev", "v=spf1", "203.0.113.10")
      expect(response.body).to include('aria-current="true"')
    end

    it "mentions the previous run of the same target", :aggregate_failures do
      earlier = create(:network_check, project:, created_at: 2.hours.ago)
      later = create(:network_check, project:, created_at: 1.hour.ago)
      get network_check_path(later), headers: turbo_headers

      expect(earlier.created_at).to be < later.created_at
      expect(response.body).to include(CGI.escapeHTML(I18n.t("network.history.previous", time: "about 2 hours", detail: I18n.t("network.dns.summary.answered", answered: 1, total: 1))))
    end

    it "shows saved port checks and pings through their own result", :aggregate_failures do
      ports = create(:network_check, :ports, project:)
      get network_check_path(ports), headers: turbo_headers

      expect(response.body).to include("ports_result", "ports_form", I18n.t("network.ports.columns.service"))

      ping = create(:network_check, :ping, project:)
      get network_check_path(ping), headers: turbo_headers

      expect(response.body).to include("ping_result", "ping_form", "443")
    end

    it "redirects plain page visits to the workspace" do
      get network_check_path(check)

      expect(response).to redirect_to(network_root_path)
    end

    it "does not show runs of other projects" do
      get network_check_path(create(:network_check)), headers: turbo_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /network/checks/:id" do
    it "deletes the run and refreshes the list", :aggregate_failures do
      expect { delete network_check_path(check), headers: turbo_headers }.to change(NetworkCheck, :count).by(-1)
      expect(response.body).to include("dns_history", I18n.t("network.history.empty"))
    end

    it "does not delete runs of other projects", :aggregate_failures do
      foreign = create(:network_check)

      expect { delete network_check_path(foreign), headers: turbo_headers }.not_to change(NetworkCheck, :count)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /network/history" do
    it "clears the history of one tool in the project", :aggregate_failures do
      ports = create(:network_check, :ports, project:)
      foreign = create(:network_check)
      delete network_history_path(kind: "dns"), headers: turbo_headers

      expect(NetworkCheck.where(id: [check.id, foreign.id, ports.id])).to contain_exactly(foreign, ports)
      expect(response.body).to include("dns_history")
    end

    it "rejects unknown tools", :aggregate_failures do
      delete network_history_path(kind: "icmp"), headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(NetworkCheck.count).to eq(1)
    end
  end
end
