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

  it "picks the icon of a channel or kind", :aggregate_failures do
    expect(helper.channel_icon(build(:notification_channel, :email))).to eq("mail")
    expect(helper.channel_icon("webhook")).to eq("webhook")
  end

  it "words a delivery error with its detail", :aggregate_failures do
    expect(helper.channel_delivery_error(build(:notification_delivery, error: "rate_limited"))).to eq(I18n.t("monitoring.delivery_errors.rate_limited"))
    expect(helper.channel_delivery_error(build(:notification_delivery, error: "unexpected_status", detail: "404"))).to eq("#{I18n.t("monitoring.delivery_errors.unexpected_status")} (404)")
  end

  it "describes the target of each kind and an expiry", :aggregate_failures do
    expect(helper.monitor_target(create(:uptime_monitor))).to eq("GET https://example.com/health")
    expect(helper.monitor_target(build(:uptime_monitor, :tcp))).to eq("example.com:5432")
    expect(helper.monitor_target(build(:uptime_monitor, :domain))).to eq("example.com")
    expect(helper.monitor_target(build(:uptime_monitor, :push))).to eq(I18n.t("monitoring.kinds.push"))
    expect(helper.monitor_expiry(build(:uptime_monitor, :ssl))).to be_nil
    expect(helper.monitor_expiry(build(:uptime_monitor, :ssl, expires_at: Time.utc(2027, 1, 15)))).to eq(I18n.t("monitoring.card.expires", date: "January 15, 2027"))
  end

  it "lists the settings of a monitor's kind", :aggregate_failures do
    http = helper.monitor_settings(create(:uptime_monitor)).to_h
    ssl = helper.monitor_settings(create(:uptime_monitor, :ssl)).to_h

    expect(http).to include(UptimeMonitor.human_attribute_name(:expected_statuses) => "200-399", UptimeMonitor.human_attribute_name(:environment) => "—")
    expect(ssl).to include(UptimeMonitor.human_attribute_name(:days_before) => 14, UptimeMonitor.human_attribute_name(:expires_at) => "—")
    expect(ssl).not_to have_key(UptimeMonitor.human_attribute_name(:expected_statuses))
    expect(helper.monitor_settings(create(:uptime_monitor, :tcp)).to_h.keys).not_to include(UptimeMonitor.human_attribute_name(:days_before))
  end
end
