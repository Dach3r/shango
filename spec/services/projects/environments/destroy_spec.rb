require "rails_helper"

RSpec.describe Projects::Environments::Destroy do
  let(:environment) { create(:environment) }

  it "destroys the environment", :aggregate_failures do
    result = described_class.call(environment:)

    expect(result).to be_success
    expect(Environment.exists?(environment.id)).to be(false)
  end

  it "fails when destroy is rejected" do
    allow(environment).to receive(:destroy).and_return(false)

    expect(described_class.call(environment:)).to be_failure
  end
end
