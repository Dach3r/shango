require "rails_helper"

RSpec.describe Network::Services do
  it "names well-known ports", :aggregate_failures do
    expect(described_class.name(22)).to eq("ssh")
    expect(described_class.name(5432)).to eq("postgresql")
  end

  it "returns nil for other ports" do
    expect(described_class.name(54_321)).to be_nil
  end
end
