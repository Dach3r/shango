require "rails_helper"

RSpec.describe "Command palette search" do
  let(:context) { sign_in_with_project }
  let(:user) { context[0] }
  let(:project) { context[1] }
  let(:collection) { create(:collection, project:, name: "Shop") }
  let(:frame) { { "Turbo-Frame" => "palette_results" } }

  before { context }

  it "requires authentication" do
    sign_out user
    get search_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "offers the pages and network tools without a query", :aggregate_failures do
    get search_path, headers: frame

    expect(response.body).to include(I18n.t("projects.searches.show.groups.pages"), overview_path, workbench_root_path, monitoring_root_path, monitoring_incidents_path, network_root_path, network_workspace_path("tls"))
    expect(response.body).not_to include(I18n.t("projects.searches.show.groups.requests"))
  end

  it "finds requests by name or URL, and monitors by name or host, in this project only", :aggregate_failures do
    request = create(:api_request, collection:, name: "List invoices", url: "https://api.example.com/billing")
    create(:api_request, collection: create(:collection, name: "Elsewhere"), name: "Invoices of others")
    monitor = create(:uptime_monitor, :tcp, project:, name: "Database", settings: { "host" => "invoices.internal", "port" => 5432 })
    get search_path(q: "invoice"), headers: frame

    expect(response.body).to include("List invoices", "Shop", workbench_request_path(request), "Database", monitoring_monitor_path(monitor), I18n.t("monitoring.kinds.tcp"))
    expect(response.body).not_to include("Invoices of others", I18n.t("projects.searches.show.groups.pages"))

    get search_path(q: "billing"), headers: frame
    expect(response.body).to include("List invoices")
  end

  it "matches page names regardless of case", :aggregate_failures do
    get search_path(q: "TLS"), headers: frame

    expect(response.body).to include(network_workspace_path("tls"))
    expect(response.body).not_to include(overview_path)
  end

  it "says when nothing matches and treats wildcards literally", :aggregate_failures do
    create(:api_request, collection:, name: "List invoices")
    get search_path(q: "%"), headers: frame

    expect(response.body).to include(I18n.t("projects.searches.show.empty"))
    expect(response.body).not_to include("List invoices")
  end

  it "bounds what it searches for and returns" do
    10.times { |index| create(:api_request, collection:, name: "Invoice #{index}") }
    get search_path(q: "invoice#{"x" * 200}"), headers: frame
    expect(response.body).to include(I18n.t("projects.searches.show.empty"))

    get search_path(q: "invoice"), headers: frame
    expect(response.body.scan("Invoice ").size).to eq(Projects::Searches::Run::LIMIT)
  end
end
