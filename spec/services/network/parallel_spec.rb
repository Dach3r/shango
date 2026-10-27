require "rails_helper"

RSpec.describe Network::Parallel do
  it "returns the block results in input order", :aggregate_failures do
    results = described_class.map([3, 1, 2], limit: 2) do |value|
      sleep(value * 0.01)
      value * 10
    end

    expect(results).to eq([30, 10, 20])
  end

  it "never runs more than `limit` blocks at once" do
    running = Concurrent::AtomicFixnum.new
    peak = Concurrent::AtomicFixnum.new

    described_class.map(Array.new(8, 0), limit: 3) do
      peak.update { |current| [current, running.increment].max }
      sleep(0.01)
      running.decrement
    end

    expect(peak.value).to be <= 3
  end

  it "returns an empty list without threads" do
    expect(described_class.map([], limit: 4) { raise "unused" }).to eq([])
  end

  it "re-raises errors from the block" do
    expect { described_class.map([1], limit: 1) { raise ArgumentError, "boom" } }.to raise_error(ArgumentError, "boom")
  end
end
