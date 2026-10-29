require "rails_helper"

RSpec.describe MonitoringHelper do
  it "words intervals in minutes or hours", :aggregate_failures do
    expect(helper.monitor_interval_label(300)).to eq(I18n.t("monitoring.intervals.minutes", value: 5))
    expect(helper.monitor_interval_label(7200)).to eq(I18n.t("monitoring.intervals.hours", value: 2))
    expect(helper.monitor_interval_options(build(:uptime_monitor)).first).to eq([I18n.t("monitoring.intervals.minutes", value: 1), 60])
  end

  it "formats uptime and response times, with a dash when missing", :aggregate_failures do
    expect(helper.monitor_uptime(99.5)).to eq("99.5%")
    expect(helper.monitor_uptime(nil)).to eq("—")
    expect(helper.monitor_ms(1234)).to eq("1,234 ms")
    expect(helper.monitor_ms(nil)).to eq("—")
  end

  it "words a cause with its detail", :aggregate_failures do
    expect(helper.monitor_cause("connection_refused")).to eq(I18n.t("monitoring.causes.connection_refused"))
    expect(helper.monitor_cause("unexpected_status", "503")).to eq("#{I18n.t("monitoring.causes.unexpected_status")} (503)")
  end
end
