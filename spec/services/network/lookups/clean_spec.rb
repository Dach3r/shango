require "rails_helper"

RSpec.describe Network::Lookups::Clean do
  it "keeps only strings, trimmed and cut", :aggregate_failures do
    expect(described_class.text("  GOOGLE  ")).to eq("GOOGLE")
    expect(described_class.text("x" * 300).length).to eq(described_class::LIMIT)
    expect(described_class.text("   ")).to be_nil
    expect(described_class.text(%w[a])).to be_nil
    expect(described_class.text(nil)).to be_nil
  end

  it "reads dates as UTC ISO 8601 and drops what it cannot read", :aggregate_failures do
    expect(described_class.time("2026-01-02T03:04:05+02:00")).to eq("2026-01-02T01:04:05Z")
    expect(described_class.time("2026-01-02")).to eq("2026-01-02T00:00:00Z")
    expect(described_class.time("2026-13-45T99:99:99Z")).to be_nil
    expect(described_class.time(20_260_102)).to be_nil
  end
end
