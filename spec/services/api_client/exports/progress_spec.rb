require "rails_helper"

RSpec.describe ApiClient::Exports::Progress do
  it "reports each new percentage of the build share once", :aggregate_failures do
    reported = []
    progress = described_class.new(total: 4) { |percent| reported << percent }

    progress.advance(1)
    progress.advance(0)
    progress.advance(3)
    progress.advance(2)

    expect(reported).to eq([22, 90])
  end

  it "is done with the build when there is nothing to write" do
    reported = []
    described_class.new(total: 0) { |percent| reported << percent }.advance(0)

    expect(reported).to eq([90])
  end

  it "works without a listener" do
    expect { described_class.new(total: 1).advance(1) }.not_to raise_error
  end
end
