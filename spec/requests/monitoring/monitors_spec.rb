require "rails_helper"

RSpec.describe "Monitoring monitors" do
  include ActiveJob::TestHelper

  let(:context) { sign_in_with_project }
  let(:user) { context[0] }
  let(:project) { context[1] }
  let(:membership) { context[2] }
  let(:params) { { uptime_monitor: { kind: "http", name: "API health", interval: "300", timeout: "10", confirmations: "2", environment_id: "", settings: { url: "https://example.com/health", http_method: "GET", expected_statuses: "200-399", max_response_ms: "" } } } }

  # Signs in a plain member of the project (another user owns it).
  def sign_in_member
    create(:membership, :owner, project:)
    membership.update!(role: "member")
  end

  before { context }

  it "requires authentication" do
    sign_out user
    get monitoring_root_path

    expect(response).to redirect_to(new_user_session_path)
  end

  describe "index" do
    it "shows an empty state with the way to create one", :aggregate_failures do
      get monitoring_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("monitoring.index.empty.title"), I18n.t("monitoring.index.empty.hint"), new_monitoring_monitor_path, "0 <span class=\"text-sm text-muted\">/ 50</span>")
      expect(response.body).to include('data-controller="refresh"')
    end

    it "lists the project's monitors with their uptime, response time and sparkline", :aggregate_failures do
      up = create(:uptime_monitor, project:, name: "Shop", creator: user, last_checked_at: 1.minute.ago, created_at: 2.days.ago)
      up.go_up
      up.save!
      create(:check_rollup, uptime_monitor: up, hour: 2.hours.ago.beginning_of_hour, responses: 2, response_ms_sum: 300)
      create(:check_rollup, uptime_monitor: up, hour: 1.hour.ago.beginning_of_hour, responses: 2, response_ms_sum: 500)
      paused = create(:uptime_monitor, project:, name: "Old site", enabled: false)
      create(:uptime_monitor, name: "Not mine")
      get monitoring_root_path

      expect(response.body).to include("Shop", "Old site", "https://example.com/health", "<polyline", "200 ms", "100%", edit_monitoring_monitor_path(up))
      expect(response.body).to include(monitoring_monitor_pause_path(paused), I18n.t("monitoring.actions.resume"), I18n.t("monitoring.statuses.paused"))
      expect(response.body).not_to include("Not mine")
    end

    it "shows the target of each kind and the expiry of a certificate", :aggregate_failures do
      create(:uptime_monitor, :tcp, project:, settings: { "host" => "db.internal", "port" => 5432 })
      create(:uptime_monitor, :ssl, project:, expires_at: Time.utc(2027, 1, 15))
      create(:uptime_monitor, :domain, project:, settings: { "host" => "shop.example" })
      create(:uptime_monitor, :push, project:)
      get monitoring_root_path

      expect(response.body).to include("db.internal:5432", "example.com:443 · #{I18n.t("monitoring.card.expires", date: "January 15, 2027")}", "shop.example", I18n.t("monitoring.card.no_ping"))
      get monitoring_root_path(q: "db.internal")
      expect(response.body).to include("db.internal:5432")
      expect(response.body).not_to include("shop.example")
    end

    it "filters by status and searches by name or URL", :aggregate_failures do
      create(:uptime_monitor, project:, name: "Shop", settings: { "url" => "https://shop.example.com" }).tap { |monitor| monitor.go_down && monitor.save! }
      create(:uptime_monitor, project:, name: "Blog", settings: { "url" => "https://blog.example.com" })
      create(:uptime_monitor, project:, name: "Paused", enabled: false)
      get monitoring_root_path(status: "down")

      expect(response.body).to include(">Shop<")
      expect(response.body).not_to include(">Blog<")

      get monitoring_root_path(status: "paused")

      expect(response.body).to include(">Paused<")
      expect(response.body).not_to include(">Shop<")

      get monitoring_root_path(q: "blog.example")

      expect(response.body).to include(">Blog<")
      expect(response.body).not_to include(">Shop<")

      get monitoring_root_path(q: "nothing", status: "bogus")

      expect(response.body).to include(I18n.t("monitoring.index.empty.filtered"))
    end

    it "hides the actions a member cannot use", :aggregate_failures do
      sign_in_member
      create(:uptime_monitor, project:, creator: create(:user))
      get monitoring_root_path

      expect(response.body).not_to include(I18n.t("monitoring.actions.edit"))
      expect(response.body).to include(new_monitoring_monitor_path)
    end
  end

  describe "show" do
    it "shows uptime, chart, incidents, settings and latest checks", :aggregate_failures do
      environment = create(:environment, project:, name: "Production")
      monitor = create(:uptime_monitor, project:, environment:, created_at: 2.days.ago, last_checked_at: 1.minute.ago)
      create(:check_rollup, uptime_monitor: monitor, hour: 2.hours.ago.beginning_of_hour)
      create(:check_rollup, uptime_monitor: monitor, hour: 1.hour.ago.beginning_of_hour)
      create(:incident, uptime_monitor: monitor, cause: "unexpected_status", detail: "503 Service Unavailable", started_at: 3.hours.ago, resolved_at: 2.hours.ago, resolution: "recovered")
      create(:incident, uptime_monitor: create(:uptime_monitor, project:), started_at: 1.hour.ago)
      create(:check_result, uptime_monitor: monitor, status: "down", error: "connection_timeout", http_status: nil, response_ms: nil)
      get monitoring_monitor_path(monitor)

      expect(response.body).to include(monitor.name, "Production", "<polyline", I18n.t("monitoring.show.uptime_month"), "120 ms")
      expect(response.body).to include(CGI.escapeHTML("#{I18n.t("monitoring.causes.unexpected_status")} (503 Service Unavailable)"), I18n.t("monitoring.causes.connection_timeout"))
      expect(response.body).to include(I18n.t("monitoring.intervals.minutes", value: 5), I18n.t("monitoring.units.seconds", value: 10))
    end

    it "shows an open incident, one closed by a pause and a monitor without data", :aggregate_failures do
      monitor = create(:uptime_monitor, project:)
      create(:incident, uptime_monitor: monitor, started_at: 2.hours.ago, resolved_at: 1.hour.ago, resolution: "paused")
      create(:incident, uptime_monitor: monitor, started_at: 10.minutes.ago)
      get monitoring_monitor_path(monitor)

      expect(response.body).to include(I18n.t("monitoring.show.ongoing"), I18n.t("monitoring.show.closed_by_pause"), I18n.t("monitoring.show.no_checks"), I18n.t("monitoring.card.no_data"))
    end

    it "shows the target, settings and expiry of an SSL monitor", :aggregate_failures do
      monitor = create(:uptime_monitor, :ssl, project:, expires_at: Time.utc(2027, 1, 15))
      get monitoring_monitor_path(monitor)

      expect(response.body).to include("example.com:443", UptimeMonitor.human_attribute_name(:days_before), UptimeMonitor.human_attribute_name(:expires_at), "January 15, 2027")
      expect(response.body).not_to include(UptimeMonitor.human_attribute_name(:expected_statuses))
    end

    it "shows a monitor without incidents" do
      get monitoring_monitor_path(create(:uptime_monitor, project:))

      expect(response.body).to include(I18n.t("monitoring.show.no_incidents"))
    end

    it "does not reach a monitor of another project" do
      get monitoring_monitor_path(create(:uptime_monitor))

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "create" do
    it "offers the form with the member's environment", :aggregate_failures do
      environment = create(:environment, project:)
      membership.update!(current_environment: environment)
      get new_monitoring_monitor_path(kind: "http")

      expect(response.body).to include(I18n.t("monitoring.new.title"), %(<option selected="selected" value="#{environment.id}">), 'data-controller="variable-autocomplete"')
    end

    it "saves the monitor and checks it right away", :aggregate_failures do
      expect { post monitoring_monitors_path, params: }.to change(project.uptime_monitors, :count).by(1).and have_enqueued_job(MonitorCheckJob)

      monitor = project.uptime_monitors.last

      expect(response).to redirect_to(monitoring_monitor_path(monitor))
      expect(monitor).to have_attributes(name: "API health", kind: "http", creator: user, interval: 300, url: "https://example.com/health", mode: "url", environment_required: false)
      expect(monitor.next_check_at).to be_between(5.minutes.from_now - 5.seconds, 6.minutes.from_now)
    end

    it "asks for the kind first", :aggregate_failures do
      get new_monitoring_monitor_path

      expect(response.body).to include(I18n.t("monitoring.new.choose"), *UptimeMonitor.kinds.keys.map { |kind| new_monitoring_monitor_path(kind:) })
      get new_monitoring_monitor_path(kind: "nope")
      expect(response.body).to include(I18n.t("monitoring.new.choose"))
    end

    it "shows the fields of each kind", :aggregate_failures do
      get new_monitoring_monitor_path(kind: "ssl")
      expect(response.body).to include('name="uptime_monitor[settings][host]"', 'value="443"', 'name="uptime_monitor[settings][days_before]"', I18n.t("monitoring.form.ssl_hint"), 'name="uptime_monitor[kind]"')
      expect(response.body).not_to include('name="uptime_monitor[settings][url]"')

      get new_monitoring_monitor_path(kind: "tcp")
      expect(response.body).to include('name="uptime_monitor[settings][port]"', I18n.t("monitoring.form.tcp_hint"))
      expect(response.body).not_to include('name="uptime_monitor[settings][days_before]"')
    end

    it "creates TCP and SSL monitors", :aggregate_failures do
      post monitoring_monitors_path, params: { uptime_monitor: { kind: "tcp", name: "DB", interval: "60", timeout: "5", confirmations: "2", settings: { host: "db.example.com", port: "5432" } } }
      post monitoring_monitors_path, params: { uptime_monitor: { kind: "ssl", name: "Cert", interval: "3600", timeout: "10", confirmations: "1", settings: { host: "example.com", port: "443", days_before: "21" } } }

      expect(project.uptime_monitors.find_by(kind: "tcp")).to have_attributes(host: "db.example.com", port: 5432, settings: { "host" => "db.example.com", "port" => 5432 })
      expect(project.uptime_monitors.find_by(kind: "ssl")).to have_attributes(host: "example.com", port: 443, days_before: 21)
    end

    it "creates a push monitor and shows its URL once", :aggregate_failures do
      post monitoring_monitors_path, params: { uptime_monitor: { kind: "push", name: "Backup", interval: "86400", confirmations: "1", settings: { grace: "3600" } } }
      monitor = project.uptime_monitors.sole

      expect(monitor).to have_attributes(kind: "push", interval: 86_400, grace: 3600)
      follow_redirect!
      url = response.body[%r{http://www\.example\.com/monitoring/push/[A-Za-z0-9_-]+}]
      expect(monitor.push_token_digest).to eq(UptimeMonitor.digest(url.split("/").last))
      expect(response.body).not_to include(monitoring_monitor_run_path(monitor))
      get monitoring_monitor_path(monitor)
      expect(response.body).not_to include(url)
    end

    it "shows the push fields without a timeout or environment", :aggregate_failures do
      get new_monitoring_monitor_path(kind: "push")

      expect(response.body).to include('name="uptime_monitor[settings][grace]"', I18n.t("monitoring.form.push_hint"), I18n.t("monitoring.intervals.days", value: 7))
      expect(response.body).not_to include('name="uptime_monitor[timeout]"', 'name="uptime_monitor[environment_id]"')
    end

    it "creates a domain monitor and refuses an unknown kind", :aggregate_failures do
      post monitoring_monitors_path, params: { uptime_monitor: { kind: "domain", name: "Domain", interval: "86400", timeout: "10", confirmations: "1", settings: { host: "example.com", days_before: "45" } } }
      expect(project.uptime_monitors.sole).to have_attributes(kind: "domain", host: "example.com", days_before: 45)

      post monitoring_monitors_path, params: { uptime_monitor: { kind: "icmp", name: "Ping", interval: "60", timeout: "10", confirmations: "1" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("monitoring.new.choose"))
      expect(project.uptime_monitors.count).to eq(1)
    end

    it "shows what is wrong with invalid input", :aggregate_failures do
      params[:uptime_monitor][:settings][:url] = ""
      expect { post monitoring_monitors_path, params: }.not_to change(UptimeMonitor, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('aria-invalid="true"', UptimeMonitor.human_attribute_name(:url))
    end
  end

  describe "update" do
    let(:monitor) { create(:uptime_monitor, project:, creator: user) }

    it "saves a change and checks the new configuration right away", :aggregate_failures do
      get edit_monitoring_monitor_path(monitor)
      params[:uptime_monitor][:settings][:url] = "https://example.com/status"

      expect(response.body).to include(I18n.t("monitoring.edit.title"), "https://example.com/health")
      expect { patch monitoring_monitor_path(monitor), params: }.to have_enqueued_job(MonitorCheckJob).with(monitor.id, monitor.config_version + 1)
      expect(response).to redirect_to(monitoring_monitor_path(monitor))
      expect(monitor.reload).to have_attributes(name: "API health", url: "https://example.com/status", expected_statuses: "200-399")
      expect(monitor.next_check_at).to be > 4.minutes.from_now
    end

    it "does not check again when the form changes nothing that is checked" do
      expect { patch monitoring_monitor_path(monitor), params: }.not_to have_enqueued_job(MonitorCheckJob)
    end

    it "does not check again when only the name changes" do
      params[:uptime_monitor][:interval] = monitor.interval.to_s

      expect { patch monitoring_monitor_path(monitor), params: { uptime_monitor: { name: "Renamed" } } }.not_to have_enqueued_job(MonitorCheckJob)
    end

    it "does not check a paused monitor after a change" do
      monitor.update!(enabled: false)

      expect { patch monitoring_monitor_path(monitor), params: }.not_to have_enqueued_job(MonitorCheckJob)
    end

    it "shows what is wrong with invalid input" do
      patch monitoring_monitor_path(monitor), params: { uptime_monitor: { name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "keeps a member away from a monitor someone else created", :aggregate_failures do
      sign_in_member
      other = create(:uptime_monitor, project:, creator: create(:user))
      patch monitoring_monitor_path(other), params:, headers: { "Accept" => "text/html" }

      expect(response).to redirect_to(workbench_root_path)
      expect(other.reload.name).not_to eq("API health")
    end
  end

  it "deletes a monitor with its history", :aggregate_failures do
    monitor = create(:uptime_monitor, project:)
    create(:check_result, uptime_monitor: monitor)

    expect { delete monitoring_monitor_path(monitor) }.to change(UptimeMonitor, :count).by(-1).and change(CheckResult, :count).by(-1)
    expect(response).to redirect_to(monitoring_root_path)
  end

  describe "alert channels" do
    let(:mine) { create(:notification_channel, project:, name: "Ops hooks") }

    it "offers the project's channels in the form, or the way to create one", :aggregate_failures do
      get new_monitoring_monitor_path(kind: "http")
      expect(response.body).to include(I18n.t("monitoring.form.no_channels"), new_monitoring_channel_path)

      mine
      get new_monitoring_monitor_path(kind: "tcp")
      expect(response.body).to include("Ops hooks", "uptime_monitor_channel_#{mine.id}")
    end

    it "attaches only channels of the project and shows them", :aggregate_failures do
      other = create(:notification_channel)
      post monitoring_monitors_path, params: params.deep_merge(uptime_monitor: { notification_channel_ids: ["", mine.id, other.id] })
      monitor = project.uptime_monitors.sole

      expect(monitor.notification_channels).to eq([mine])
      get monitoring_monitor_path(monitor)
      expect(response.body).to include("Ops hooks")
    end

    it "replaces or clears the channels on update", :aggregate_failures do
      monitor = create(:uptime_monitor, project:, creator: user)
      monitor.notification_channels = [mine]
      patch monitoring_monitor_path(monitor), params: { uptime_monitor: { name: monitor.name, notification_channel_ids: [""] } }

      expect(monitor.reload.notification_channels).to be_empty
      patch monitoring_monitor_path(monitor), params: { uptime_monitor: { name: "Kept" } }
      expect(monitor.reload.name).to eq("Kept")
    end

    it "keeps the channels as they were when the change is invalid", :aggregate_failures do
      monitor = create(:uptime_monitor, project:, creator: user)
      monitor.notification_channels = [mine]
      patch monitoring_monitor_path(monitor), params: { uptime_monitor: { name: "", notification_channel_ids: [""] } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(monitor.reload.notification_channels).to eq([mine])
    end

    it "caps the channels of a monitor" do
      stub_const("MonitorChannel::PER_MONITOR", 1)
      post monitoring_monitors_path, params: params.deep_merge(uptime_monitor: { notification_channel_ids: [mine.id, create(:notification_channel, project:).id] })

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
