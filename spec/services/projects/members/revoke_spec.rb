require "rails_helper"

RSpec.describe Projects::Members::Revoke do
  let(:project) { create(:project) }
  let!(:owner) { create(:membership, :owner, project:) }
  let(:actor) { owner.user }

  it "revokes a member and keeps the record as history", :aggregate_failures do
    member = create(:membership, project:)
    result = described_class.call(membership: member, actor:)

    expect(result).to be_success
    expect(member.reload).not_to be_active
    expect(Membership.exists?(member.id)).to be(true)
  end

  it "refuses to revoke the last owner", :aggregate_failures do
    result = described_class.call(membership: owner, actor:)

    expect(result).to be_failure
    expect(result.error).to eq(:last_owner)
    expect(owner.reload).to be_active
  end

  it "lets one of several owners go" do
    create(:membership, :owner, project:)

    expect(described_class.call(membership: owner, actor:)).to be_success
  end

  describe "history" do
    it "records who removed whom", :aggregate_failures do
      member = create(:membership, project:)
      described_class.call(membership: member, actor:)
      event = AuditEvent.last

      expect(event).to have_attributes(project:, kind: "member_revoked", actor:, target: member.user)
    end

    it "records leaving when members revoke themselves", :aggregate_failures do
      member = create(:membership, project:)
      described_class.call(membership: member, actor: member.user)

      expect(AuditEvent.last).to have_attributes(kind: "member_left", actor: member.user, target: member.user)
    end

    it "records nothing when the revocation is refused" do
      expect { described_class.call(membership: owner, actor:) }.not_to change(AuditEvent, :count)
    end
  end
end
