require "rails_helper"

RSpec.describe Network::Variables do
  let(:environment) { create(:environment) }

  def call(raw, environment: nil)
    described_class.call(raw:, environment:)
  end

  it "returns plain text untouched" do
    expect(call("example.com").record).to eq("example.com")
  end

  it "resolves variables of the environment and the dynamic helpers", :aggregate_failures do
    create(:variable, environment:, key: "ip", value: "203.0.113.10")

    expect(call("{{ip}}", environment:).record).to eq("203.0.113.10")
    expect(call("{{$randomInt}}", environment:).record).to match(/\A\d+\z/)
  end

  it "ignores disabled variables", :aggregate_failures do
    create(:variable, environment:, key: "ip", value: "203.0.113.10", enabled: false)
    result = call("{{ip}}", environment:)

    expect(result).to be_failure
    expect(result.error).to eq(:unresolved_variable)
  end

  it "fails for a variable that is not defined", :aggregate_failures do
    result = call("{{nope}}")

    expect(result.error).to eq(:unresolved_variable)
    expect(result.data[:name]).to eq("nope")
  end

  it "refuses secret variables", :aggregate_failures do
    create(:variable, environment:, key: "token", value: "s3cret", secret: true)
    result = call("{{token}}", environment:)

    expect(result.error).to eq(:secret_variable)
    expect(result.data[:name]).to eq("token")
  end
end
