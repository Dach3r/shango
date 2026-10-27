require "rails_helper"

RSpec.describe Users::AccountImpact do
  subject(:impact) { described_class.new(user) }

  let(:user) { create(:user) }

  it "lists the projects only the user belongs to, with their requests", :aggregate_failures do
    project = create(:project)
    create(:membership, :owner, user:, project:)
    create_list(:api_request, 2, collection: create(:collection, project:), project:)

    expect(impact.doomed).to eq([project])
    expect(impact.requests_count).to eq(2)
    expect(impact).not_to be_blocked
  end

  it "ignores projects where the user is a plain member or has a co-owner", :aggregate_failures do
    member_of = create(:project)
    create(:membership, :owner, project: member_of)
    create(:membership, user:, project: member_of)
    co_owned = create(:project)
    create(:membership, :owner, user:, project: co_owned)
    create(:membership, :owner, project: co_owned)

    expect(impact.doomed).to be_empty
    expect(impact.blocked).to be_empty
  end

  it "flags projects where the user is the only owner of other members", :aggregate_failures do
    project = create(:project)
    create(:membership, :owner, user:, project:)
    create(:membership, project:)

    expect(impact.blocked).to eq([project])
    expect(impact).to be_blocked
    expect(impact.doomed).to be_empty
  end
end
