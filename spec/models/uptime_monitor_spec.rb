require "rails_helper"

RSpec.describe UptimeMonitor do
  let(:project) { create(:project) }

  def monitor(*traits, **attributes)
    build(:uptime_monitor, *traits, project:, **attributes)
  end

  def errors_on(*traits, **attributes)
    record = monitor(*traits, **attributes)
    record.validate
    record.errors.attribute_names
  end

  it "is valid for every kind with its defaults", :aggregate_failures do
    [[], [:request], [:tcp], [:ssl], [:domain], [:push]].each do |traits|
      expect(monitor(*traits)).to be_valid, traits.inspect
    end
  end

  it "keeps the kind and status as strings with a database check", :aggregate_failures do
    expect(described_class.kinds.values).to eq(%w[http tcp ssl domain push])
    expect(described_class.statuses.values).to eq(%w[pending up down])
    record = create(:uptime_monitor, project:)

    expect(record).to be_pending
    expect(monitor(kind: "icmp")).not_to be_valid
    expect { record.update_columns(kind: "icmp") }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "keeps the status to known values in the database" do
    expect { create(:uptime_monitor, project:).update_columns(status: "paused") }.to raise_error(ActiveRecord::StatementInvalid)
  end

  describe "settings" do
    it "fills the defaults of the kind, casts numbers and drops fields of other kinds", :aggregate_failures do
      record = monitor(settings: { "url" => " https://example.com ", "host" => "x", "max_response_ms" => "800", "expected_statuses" => "200, 301-302" })
      record.validate

      expect(record.settings).to eq("mode" => "url", "http_method" => "GET", "expected_statuses" => "200,301-302", "url" => "https://example.com", "max_response_ms" => 800)
      expect(monitor(:ssl).tap(&:validate).settings).to eq("host" => "example.com", "port" => 443, "days_before" => 14)
      expect(monitor(:domain).tap(&:validate).days_before).to eq(30)
      expect(monitor(:push).tap(&:validate).grace).to eq(300)
    end

    it "validates an HTTP monitor of a URL", :aggregate_failures do
      expect(errors_on(settings: { "mode" => "ftp" })).to eq([:mode])
      expect(errors_on(settings: { "url" => "" })).to eq([:url])
      expect(errors_on(settings: { "url" => "https://example.com/#{"a" * 2048}" })).to eq([:url])
      expect(errors_on(settings: { "url" => "https://example.com", "http_method" => "POST" })).to eq([:http_method])
      expect(errors_on(settings: { "url" => "https://example.com", "max_response_ms" => "0" })).to eq([:max_response_ms])
      expect(errors_on(settings: { "url" => "https://example.com", "max_response_ms" => "1.5" })).to eq([:max_response_ms])
    end

    it "validates the expected statuses", :aggregate_failures do
      %w[200 200-299 200,301-302,404].each { |list| expect(errors_on(settings: { "url" => "https://example.com", "expected_statuses" => list })).to be_empty, list }
      %w[2xx 200- 099 600 300-200 200-600].each { |list| expect(errors_on(settings: { "url" => "https://example.com", "expected_statuses" => list })).to eq([:expected_statuses]), list }
    end

    it "needs a saved request in request mode" do
      expect(errors_on(settings: { "mode" => "request" })).to eq([:api_request])
    end

    it "validates hosts, ports and thresholds", :aggregate_failures do
      expect(errors_on(:tcp, settings: { "host" => "", "port" => 22 })).to eq([:host])
      expect(errors_on(:tcp, settings: { "host" => "a" * 254, "port" => 22 })).to eq([:host])
      expect(errors_on(:tcp, settings: { "host" => "example.com", "port" => 70_000 })).to eq([:port])
      expect(errors_on(:tcp, settings: { "host" => "example.com" })).to eq([:port])
      expect(errors_on(:ssl, settings: { "host" => "example.com", "days_before" => 91 })).to eq([:days_before])
      expect(errors_on(:domain, settings: { "host" => "", "days_before" => 0 })).to eq([:host])
      expect(errors_on(:domain, settings: { "host" => "example.com", "days_before" => 366 })).to eq([:days_before])
      expect(errors_on(:push, settings: { "grace" => -1 })).to eq([:grace])
    end
  end

  it "accepts only the intervals of its kind", :aggregate_failures do
    expect(errors_on(interval: 30)).to eq([:interval])
    expect(errors_on(:domain, interval: 300)).to eq([:interval])
    expect(errors_on(:push, interval: 90)).to be_empty
    expect(errors_on(:push, interval: 604_801)).to eq([:interval])
    expect(monitor(:domain).intervals).to eq(described_class::DOMAIN_INTERVALS)
  end

  it "bounds the timeout and confirmations", :aggregate_failures do
    expect(errors_on(timeout: 31)).to eq([:timeout])
    expect(errors_on(confirmations: 0)).to eq([:confirmations])
  end

  it "only references an environment and a request of its own project", :aggregate_failures do
    expect(errors_on(environment: create(:environment))).to eq([:environment])
    expect(errors_on(:request, api_request: create(:api_request))).to eq([:api_request])
    expect(errors_on(environment: create(:environment, project:))).to be_empty
  end

  it "cannot change its kind", :aggregate_failures do
    record = create(:uptime_monitor, project:)

    expect(record.update(kind: "tcp", settings: { "host" => "example.com", "port" => 22 })).to be(false)
    expect(record.errors.details[:kind]).to eq([{ error: :immutable }])
  end

  it "stops at the limits of the project and of the install", :aggregate_failures do
    stub_const("ENV", ENV.to_h.merge("SHANGO_MONITORS_PER_PROJECT" => "1"))
    create(:uptime_monitor, project:)
    record = monitor

    expect(record).not_to be_valid
    expect(record.errors.details[:base]).to eq([{ error: :project_limit, count: 1 }])

    stub_const("ENV", ENV.to_h.merge("SHANGO_MONITORS_PER_PROJECT" => "5", "SHANGO_MONITORS_TOTAL" => "1"))

    expect(monitor.tap(&:validate).errors.details[:base]).to eq([{ error: :total_limit, count: 1 }])
    expect(described_class.per_project_limit).to eq(5)
  end

  it "needs a project" do
    expect(build(:uptime_monitor, project: nil).tap(&:validate).errors.attribute_names).to eq([:project])
  end

  it "has no install limit by default" do
    expect(described_class.total_limit).to be_nil
  end

  it "bumps the config version only when what is checked changes", :aggregate_failures do
    record = create(:uptime_monitor, project:)

    expect { record.update!(status: "up", failures: 1, last_checked_at: Time.current, next_check_at: 1.minute.from_now, name: "Renamed") }.not_to change(record, :config_version)
    expect { record.update!(enabled: false) }.to change(record, :config_version).by(1)
    expect { record.update!(settings: record.settings.merge("url" => "https://example.com/other")) }.to change(record, :config_version).by(1)
    expect(record).to be_paused
  end

  it "remembers that it needs an environment once saved with one", :aggregate_failures do
    environment = create(:environment, project:)
    record = create(:uptime_monitor, project:, environment:)

    expect(record).to be_environment_required

    environment.destroy

    expect(record.reload).to have_attributes(environment_id: nil, environment_required: true)

    record.update!(environment: create(:environment, project:))
    record.update!(environment: nil)

    expect(record).not_to be_environment_required
  end

  it "keeps only the digest of a push token", :aggregate_failures do
    record = monitor(:push)
    token = record.regenerate_push_token
    record.save!

    expect(record.push_token_digest).to eq(Digest::SHA256.hexdigest(token))
    expect(described_class.find_by_push_token(token)).to eq(record)
    expect(described_class.find_by_push_token("")).to be_nil
    expect(described_class.find_by_push_token("other")).to be_nil
  end

  it "loses its results, rollups and incidents with it and is lost with its project", :aggregate_failures do
    record = create(:uptime_monitor, project:)
    create(:check_result, uptime_monitor: record)
    create(:check_rollup, uptime_monitor: record)
    create(:incident, uptime_monitor: record)

    expect { record.destroy }.to change(CheckResult, :count).by(-1).and change(CheckRollup, :count).by(-1).and change(Incident, :count).by(-1)

    create(:incident, uptime_monitor: create(:uptime_monitor, project:))

    expect { project.destroy }.to change(described_class, :count).by(-1).and change(Incident, :count).by(-1)
  end

  it "keeps going when its saved request is deleted" do
    record = create(:uptime_monitor, :request, project:)
    record.api_request.destroy

    expect(record.reload.api_request_id).to be_nil
  end
end
