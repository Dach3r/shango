require "rails_helper"

RSpec.describe "Monitoring incidents" do
  let(:context) { sign_in_with_project }
  let(:user) { context[0] }
  let(:project) { context[1] }
  let(:membership) { context[2] }
  let(:monitor) { create(:uptime_monitor, project:, name: "API health") }

  before { context }

  it "requires authentication" do
    sign_out user
    get monitoring_incidents_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "says when there are none", :aggregate_failures do
    get monitoring_incidents_path

    expect(response.body).to include(I18n.t("monitoring.incidents.empty.all"))
    get monitoring_incidents_path(state: "open")
    expect(response.body).to include(I18n.t("monitoring.incidents.empty.open"))
    get monitoring_incidents_path(state: "resolved")
    expect(response.body).to include(I18n.t("monitoring.incidents.empty.resolved"))
  end

  describe "listing" do
    let!(:open_incident) { create(:incident, uptime_monitor: monitor) }
    let!(:resolved) { create(:incident, uptime_monitor: create(:uptime_monitor, project:, name: "Old news"), started_at: 2.hours.ago, resolved_at: 1.hour.ago, resolution: "recovered") }
    let!(:paused) { create(:incident, uptime_monitor: create(:uptime_monitor, project:, name: "Paused one"), started_at: 3.hours.ago, resolved_at: 2.hours.ago, resolution: "paused") }

    it "lists every incident newest first with the monitor and the cause", :aggregate_failures do
      get monitoring_incidents_path

      expect(response.body).to include("API health", "Old news", I18n.t("monitoring.causes.connection_timeout"), I18n.t("monitoring.show.closed_by_pause"), monitoring_monitor_path(monitor))
      expect(response.body.index("API health")).to be < response.body.index("Old news")
    end

    it "filters by state and ignores an unknown one", :aggregate_failures do
      get monitoring_incidents_path(state: "open")
      expect(response.body).to include("API health")
      expect(response.body).not_to include("Old news")

      get monitoring_incidents_path(state: "resolved")
      expect(response.body).to include("Old news")
      expect(response.body).not_to include("API health")

      get monitoring_incidents_path(state: "nope")
      expect(response.body).to include("API health", "Old news")
    end

    it "never lists another project's incidents" do
      create(:incident, uptime_monitor: create(:uptime_monitor, name: "Elsewhere"))
      get monitoring_incidents_path

      expect(response.body).not_to include("Elsewhere")
    end

    it "narrows to the selected environment unless asked for all", :aggregate_failures do
      production = create(:environment, project:)
      monitor.update!(environment: production)
      resolved.uptime_monitor.update!(environment: create(:environment, project:))
      membership.update!(current_environment: production)
      get monitoring_incidents_path

      expect(response.body).to include("API health", I18n.t("projects.environment_scope.show_all"))
      expect(response.body).not_to include("Old news")

      get monitoring_incidents_path(environment: "all")
      expect(response.body).to include("API health", "Old news")
    end
  end

  describe "pages" do
    before do
      stub_const("Monitoring::IncidentsController::PER_PAGE", 2)
      5.times { |index| create(:incident, uptime_monitor: create(:uptime_monitor, project:, name: "Monitor #{index}"), started_at: (index + 1).minutes.ago, resolved_at: index.minutes.ago, resolution: "recovered") }
    end

    it "pages through the incidents", :aggregate_failures do
      get monitoring_incidents_path

      expect(response.body).to include("Monitor 0", "Monitor 1", I18n.t("projects.audit_events.index.older"), "page=2")
      expect(response.body).not_to include("Monitor 2", I18n.t("projects.audit_events.index.newer"))

      get monitoring_incidents_path(page: 2, environment: "all")
      expect(response.body).to include("Monitor 2", "Monitor 3", I18n.t("projects.audit_events.index.newer"), I18n.t("projects.audit_events.index.older"))
      expect(response.body).not_to include("page=1")

      get monitoring_incidents_path(page: 3)
      expect(response.body).to include("Monitor 4", "page=2")
      expect(response.body).not_to include(I18n.t("projects.audit_events.index.older"))
    end
  end

  describe "flags" do
    it "shows the open count in the status bar, the Monitoring sidebar and the navigation", :aggregate_failures do
      create(:incident, uptime_monitor: monitor)
      get monitoring_root_path

      expect(response.body).to include(I18n.t("components.status_bar.incidents", total: 1), monitoring_incidents_path(state: "open"))

      get account_path, headers: { "Turbo-Frame" => "right_sidebar" }
      expect(response.body).to include(I18n.t("components.tools_nav.monitoring"), "border-danger/40")
    end

    it "shows nothing when no incident is open", :aggregate_failures do
      get monitoring_root_path

      expect(response.body).not_to include(I18n.t("components.status_bar.incidents", total: 0))
      get account_path, headers: { "Turbo-Frame" => "right_sidebar" }
      expect(response.body).not_to include("border-danger/40")
    end
  end
end
