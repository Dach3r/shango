require "rails_helper"

RSpec.describe ApplicationHelper do
  it "exposes the app name" do
    expect(described_class::CONFIG).to eq(name: "Shango")
  end
end
