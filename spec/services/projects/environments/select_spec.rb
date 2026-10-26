require "rails_helper"

RSpec.describe Projects::Environments::Select do
  let(:membership) { create(:membership) }
  let(:environment) { create(:environment, project: membership.project) }

  it "selects an environment of the project", :aggregate_failures do
    result = described_class.call(membership:, environment_id: environment.id)

    expect(result.record).to eq(environment)
    expect(membership.reload.current_environment).to eq(environment)
  end

  it "clears the selection with a blank id", :aggregate_failures do
    membership.update!(current_environment: environment)
    result = described_class.call(membership:, environment_id: "")

    expect(result.record).to be_nil
    expect(membership.reload.current_environment).to be_nil
  end

  it "does not select environments of other projects" do
    other = create(:environment)

    expect { described_class.call(membership:, environment_id: other.id) }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
