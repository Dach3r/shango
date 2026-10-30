require "rails_helper"

RSpec.describe "Monitoring monitor runs" do
  include ActiveJob::TestHelper

  let(:context) { sign_in_with_project }
  let(:project) { context[1] }
  let(:monitor) { create(:uptime_monitor, project:) }

  before { context }

  it "queues a check now", :aggregate_failures do
    expect { post monitoring_monitor_run_path(monitor) }.to have_enqueued_job(MonitorCheckJob).with(monitor.id, monitor.config_version)
    expect(response).to redirect_to(monitoring_monitor_path(monitor))
    expect(flash[:notice]).to be_nil
  end

  it "does not check a paused monitor", :aggregate_failures do
    monitor.update!(enabled: false)

    expect { post monitoring_monitor_run_path(monitor) }.not_to have_enqueued_job(MonitorCheckJob)
    expect(flash[:alert]).to eq(I18n.t("monitoring.monitors.runs.create.paused"))
  end

  describe "throttling" do
    before do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      stub_const("ENV", ENV.to_h.merge("SHANGO_RATE_LIMIT_NETWORK" => "1/60"))
    end

    it "shares the network limit" do
      2.times { post monitoring_monitor_run_path(monitor) }

      expect(flash[:alert]).to eq(I18n.t("throttling.limited"))
    end
  end
end
