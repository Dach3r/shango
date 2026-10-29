require "rails_helper"

RSpec.describe MonitoringDispatchJob do
  it "dispatches the due monitors" do
    allow(Monitoring::Monitors::Dispatch).to receive(:call)
    described_class.perform_now

    expect(Monitoring::Monitors::Dispatch).to have_received(:call)
  end

  it "is scheduled every minute in production and development", :aggregate_failures do
    schedule = YAML.load_file(Rails.root.join("config/recurring.yml"))

    %w[production development].each do |environment|
      expect(schedule.dig(environment, "monitoring_dispatch")).to eq("class" => "MonitoringDispatchJob", "schedule" => "every minute")
    end
  end
end
