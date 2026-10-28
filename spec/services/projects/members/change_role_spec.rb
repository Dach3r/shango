require "rails_helper"

RSpec.describe Projects::Members::ChangeRole do
  let(:project) { create(:project) }
  let!(:owner) { create(:membership, :owner, project:) }
  let(:member) { create(:membership, project:) }

  it "promotes a member", :aggregate_failures do
    result = described_class.call(membership: member, role: "owner")

    expect(result).to be_success
    expect(member.reload).to be_owner
  end

  it "demotes an owner while another remains", :aggregate_failures do
    member.update!(role: :owner)
    result = described_class.call(membership: owner, role: "member")

    expect(result).to be_success
    expect(owner.reload).to be_member
  end

  it "keeps the last owner", :aggregate_failures do
    result = described_class.call(membership: owner, role: "member")

    expect(result).to be_failure
    expect(result.error).to eq(:last_owner)
    expect(owner.reload).to be_owner
  end

  it "rejects roles that do not exist", :aggregate_failures do
    result = described_class.call(membership: member, role: "admin")

    expect(result.error).to eq(:invalid_role)
    expect(member.reload).to be_member
  end
end
