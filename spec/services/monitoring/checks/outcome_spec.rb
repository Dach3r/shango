require "rails_helper"

RSpec.describe Monitoring::Checks::Outcome do
  it "builds up, down and unknown outcomes with empty defaults", :aggregate_failures do
    expect(described_class.up(response_ms: 10)).to have_attributes(status: "up", response_ms: 10, error: nil, timings: {})
    expect(described_class.down(:refused, detail: "no")).to have_attributes(status: "down", error: "refused", detail: "no")
    expect(described_class.unknown(:rdap_unavailable)).to have_attributes(status: "unknown", error: "rdap_unavailable")
  end
end
