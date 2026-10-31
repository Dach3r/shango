require "rails_helper"

RSpec.describe ApiClient::VariableWriteback do
  let(:project) { create(:project) }
  let(:environment) { create(:environment, project:) }
  let(:owner) { create(:user) }
  let(:values) { { "token" => "abc" } }
  let(:secrets) { [] }
  let(:result) { described_class.call(environment:, user: owner, values:, secrets:) }

  before { create(:membership, :owner, user: owner, project:) }

  it "creates the variable", :aggregate_failures do
    expect(result).to be_success
    expect(result.record).to eq(1)
    expect(environment.variables.find_by(key: "token")).to have_attributes(value: "abc", secret: false, enabled: true)
  end

  it "marks a new variable secret when asked" do
    described_class.call(environment:, user: owner, values:, secrets: ["token"])

    expect(environment.variables.find_by(key: "token")).to be_secret
  end

  it "updates an existing variable, keeping its secret flag and switching it on", :aggregate_failures do
    create(:variable, :secret, environment:, key: "token", value: "old", enabled: false)

    result
    variable = environment.variables.find_by(key: "token")

    expect(variable).to have_attributes(value: "abc", secret: true, enabled: true)
  end

  it "refreshes the environment so the next run sees the value" do
    environment.variable_values
    result

    expect(environment.variable_values).to include("token" => "abc")
  end

  it "writes nothing when there is nothing to write" do
    expect(described_class.call(environment:, user: owner, values: {})).to have_attributes(record: 0)
  end

  it "needs an environment" do
    expect(described_class.call(environment: nil, user: owner, values:)).to have_attributes(error: :no_environment)
  end

  it "does not let a member edit an environment someone else created", :aggregate_failures do
    member = create(:user)
    create(:membership, user: member, project:)

    result = described_class.call(environment:, user: member, values:)

    expect(result).to have_attributes(error: :not_permitted)
    expect(environment.variables).to be_empty
  end

  it "lets a member edit the environment they created" do
    member = create(:user)
    create(:membership, user: member, project:)
    environment.update!(creator: member)

    expect(described_class.call(environment:, user: member, values:)).to be_success
  end

  it "ignores users outside the project and revoked members", :aggregate_failures do
    outsider = create(:user)
    revoked = create(:user)
    create(:membership, :revoked, user: revoked, project:)

    expect(described_class.call(environment:, user: outsider, values:)).to have_attributes(error: :not_permitted)
    expect(described_class.call(environment:, user: revoked, values:)).to have_attributes(error: :not_permitted)
    expect(described_class.call(environment:, user: nil, values:)).to have_attributes(error: :not_permitted)
  end
end
