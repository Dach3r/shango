require "rails_helper"

RSpec.describe "Project overview" do
  let(:context) { sign_in_with_project }
  let(:user) { context[0] }
  let(:project) { context[1] }
  let(:membership) { context[2] }

  before { context }

  it "requires authentication" do
    sign_out user
    get overview_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "is where the root leads" do
    get root_path

    expect(response).to redirect_to(overview_path)
  end

  it "offers the first steps in a project with nothing in it", :aggregate_failures do
    get overview_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("projects.overviews.show.empty.title"), workbench_drafts_path, new_monitoring_monitor_path, network_root_path)
    expect(response.body).not_to include(I18n.t("projects.overviews.show.incidents"))
  end

  it "shows monitors, open incidents, activity and the member's own runs", :aggregate_failures do
    monitor = create(:uptime_monitor, project:, name: "API health")
    monitor.update_columns(status: "down")
    create(:incident, uptime_monitor: monitor)
    create(:incident, uptime_monitor: create(:uptime_monitor, project:, name: "Recovered"), resolved_at: 1.minute.ago, resolution: "recovered")
    create(:audit_event, project:, actor: user, kind: "environment_created", metadata: { "name" => "Staging" })
    create(:audit_event, project:, kind: "member_left")
    api_request = create(:api_request, collection: create(:collection, project:), name: "List users")
    create(:request_execution, api_request:, project:, user:, status: 503)
    create(:request_execution, api_request: create(:api_request, collection: create(:collection, project:), name: "Their call"), project:, user: create(:user))
    create(:network_check, project:, user:, target: "shango.dev")
    get overview_path

    expect(response.body).to include("API health", I18n.t("monitoring.causes.connection_timeout"), "Staging", "List users", "503", I18n.t("network.tabs.dns"), monitoring_monitor_path(monitor))
    expect(response.body).not_to include("Recovered", "Their call", I18n.t("projects.audit_events.index.kinds.member_left", actor: "", target: "", email: "").strip)
    expect(response.body).not_to include(I18n.t("projects.overviews.show.no_incidents"), I18n.t("projects.overviews.show.no_runs"))
  end

  it "says when there is nothing to show yet", :aggregate_failures do
    create(:collection, project:)
    get overview_path

    expect(response.body).to include(I18n.t("projects.overviews.show.no_incidents"), I18n.t("projects.overviews.show.no_activity"), I18n.t("projects.overviews.show.no_runs"))
  end

  it "never shows another project's data" do
    other = create(:uptime_monitor, name: "Elsewhere")
    other.update_columns(status: "down")
    create(:incident, uptime_monitor: other)
    create(:audit_event, kind: "environment_created", metadata: { "name" => "Foreign" })
    create(:collection, project:)
    get overview_path

    expect(response.body).not_to include("Elsewhere", "Foreign")
  end

  describe "environment" do
    let(:production) { create(:environment, project:, name: "Production") }
    let(:staging) { create(:environment, project:, name: "Staging") }

    before do
      create(:incident, uptime_monitor: create(:uptime_monitor, project:, name: "In production", environment: production))
      create(:incident, uptime_monitor: create(:uptime_monitor, project:, name: "In staging", environment: staging))
      create(:incident, uptime_monitor: create(:uptime_monitor, :push, project:, name: "Heartbeat"))
      membership.update!(current_environment: production)
    end

    it "narrows monitors and incidents to the selected one and those without an environment", :aggregate_failures do
      get overview_path

      expect(response.body).to include("In production", "Heartbeat", I18n.t("projects.environment_scope.narrowed", environment: "Production"), I18n.t("projects.environment_scope.show_all"))
      expect(response.body).not_to include("In staging")
    end

    it "shows every environment when asked, with the way back", :aggregate_failures do
      get overview_path(environment: "all")

      expect(response.body).to include("In production", "In staging", I18n.t("projects.environment_scope.all"), I18n.t("projects.environment_scope.only", environment: "Production"))
    end

    it "keeps the other parameters of the page in the links", :aggregate_failures do
      get overview_path(foo: "1")

      expect(response.body).to include(CGI.escapeHTML("#{overview_path}?environment=all&foo=1"))
    end

    it "says nothing about environments when none is selected" do
      membership.update!(current_environment: nil)
      get overview_path

      expect(response.body).not_to include(I18n.t("projects.environment_scope.show_all"))
    end
  end
end
