require "rails_helper"

RSpec.describe Monitoring::Monitors::Update do
  include ActiveJob::TestHelper

  let(:monitor) { create(:uptime_monitor, settings: { "url" => "https://example.com", "max_response_ms" => 500 }) }

  it "merges the submitted settings into the current ones and checks the new configuration", :aggregate_failures do
    expect { described_class.call(monitor:, attributes: { settings: { url: "https://example.com/v2" } }) }.to have_enqueued_job(MonitorCheckJob).with(monitor.id, 1)
    expect(monitor.reload.settings).to include("url" => "https://example.com/v2", "max_response_ms" => 500, "mode" => "url")
  end

  it "records whether the monitor needs an environment" do
    environment = create(:environment, project: monitor.project)
    described_class.call(monitor:, attributes: { "environment_id" => environment.id })

    expect(monitor.reload).to be_environment_required
  end

  it "keeps an invalid change unsaved" do
    expect(described_class.call(monitor:, attributes: { timeout: 99 })).to have_attributes(failure?: true, error: :invalid)
  end
end
