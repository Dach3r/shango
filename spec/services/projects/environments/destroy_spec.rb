require "rails_helper"

RSpec.describe Projects::Environments::Destroy do
  let(:environment) { create(:environment) }

  it "destroys the environment", :aggregate_failures do
    result = described_class.call(environment:)

    expect(result).to be_success
    expect(Environment.exists?(environment.id)).to be(false)
  end

  it "records who deleted it" do
    actor = create(:user)
    described_class.call(environment:, actor:)

    expect(AuditEvent.sole).to have_attributes(kind: "environment_deleted", actor:, metadata: include("name" => environment.name))
  end

  it "fails when destroy is rejected", :aggregate_failures do
    allow(environment).to receive(:destroy).and_return(false)

    expect(described_class.call(environment:)).to be_failure
    expect(AuditEvent.count).to eq(0)
  end
end
