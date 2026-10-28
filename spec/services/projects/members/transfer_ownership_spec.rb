require "rails_helper"

RSpec.describe Projects::Members::TransferOwnership do
  let(:project) { create(:project) }
  let!(:owner) { create(:membership, :owner, project:) }
  let(:member) { create(:membership, project:) }

  it "makes the target an owner and the current owner a member", :aggregate_failures do
    result = described_class.call(from: owner, to: member)

    expect(result).to be_success
    expect(member.reload).to be_owner
    expect(owner.reload).to be_member
  end

  it "records the handover", :aggregate_failures do
    described_class.call(from: owner, to: member)

    expect(AuditEvent.last).to have_attributes(project:, kind: "ownership_transferred", actor: owner.user, target: member.user)
  end

  it "only lets an owner hand the project over", :aggregate_failures do
    result = described_class.call(from: member, to: owner)

    expect(result.error).to eq(:invalid_target)
    expect(owner.reload).to be_owner
  end

  it "refuses revoked targets, yourself and members of other projects", :aggregate_failures do
    [create(:membership, :revoked, project:), owner, create(:membership)].each do |target|
      expect(described_class.call(from: owner, to: target).error).to eq(:invalid_target)
    end
    expect(owner.reload).to be_owner
  end
end
