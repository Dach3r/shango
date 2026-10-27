require "rails_helper"

RSpec.describe Shango::ExecutionMode do
  def env(values)
    stub_const("ENV", ENV.to_h.merge(values))
  end

  it "is inline outside production", :aggregate_failures do
    expect(described_class.mode).to eq("inline")
    expect(described_class.async?).to be(false)
  end

  it "is async by default in production" do
    allow(Rails.env).to receive(:production?).and_return(true)

    expect(described_class.async?).to be(true)
  end

  it "follows the environment variable", :aggregate_failures do
    env("SHANGO_EXECUTION_MODE" => "async")
    expect(described_class.async?).to be(true)

    allow(Rails.env).to receive(:production?).and_return(true)
    env("SHANGO_EXECUTION_MODE" => "inline")
    expect(described_class.async?).to be(false)
  end

  it "rejects unknown modes" do
    env("SHANGO_EXECUTION_MODE" => "turbo")

    expect { described_class.mode }.to raise_error(ArgumentError, /must be one of async, inline/)
  end
end
