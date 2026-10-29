require "rails_helper"

RSpec.describe Monitoring::Checks::Run do
  it "runs the probe of the monitor's kind", :aggregate_failures do
    monitor = build(:uptime_monitor)
    outcome = Monitoring::Checks::Outcome.up
    probe = class_double(Monitoring::Checks::Run, call: outcome)
    stub_const("#{described_class}::PROBES", { "http" => probe })

    expect(described_class.call(monitor)).to eq(outcome)
    expect(described_class.kinds).to eq(%w[http])
  end

  it "is unknown for a kind without a probe" do
    expect(described_class.call(build(:uptime_monitor, kind: "icmp"))).to have_attributes(status: "unknown", error: "unsupported_kind")
  end
end
