require "rails_helper"

RSpec.describe Projects::Members::ChangeRole do
  let(:project) { create(:project) }
  let!(:owner) { create(:membership, :owner, project:) }
  let(:member) { create(:membership, project:) }

  it "promotes a member", :aggregate_failures do
    result = described_class.call(membership: member, role: "owner", actor: owner.user)

    expect(result).to be_success
    expect(member.reload).to be_owner
  end

  it "demotes an owner while another remains", :aggregate_failures do
    member.update!(role: :owner)
    result = described_class.call(membership: owner, role: "member", actor: owner.user)

    expect(result).to be_success
    expect(owner.reload).to be_member
  end

  it "keeps the last owner", :aggregate_failures do
    result = described_class.call(membership: owner, role: "member", actor: owner.user)

    expect(result).to be_failure
    expect(result.error).to eq(:last_owner)
    expect(owner.reload).to be_owner
  end

  it "rejects roles that do not exist", :aggregate_failures do
    result = described_class.call(membership: member, role: "admin", actor: owner.user)

    expect(result.error).to eq(:invalid_role)
    expect(member.reload).to be_member
  end

  describe "history" do
    it "records the change with both roles", :aggregate_failures do
      described_class.call(membership: member, role: "owner", actor: owner.user)

      expect(AuditEvent.last).to have_attributes(kind: "role_changed", actor: owner.user, target: member.user, metadata: include("from" => "member", "to" => "owner"))
    end

    it "records nothing when the role stays the same" do
      expect { described_class.call(membership: member, role: "member", actor: owner.user) }.not_to change(AuditEvent, :count)
    end

    it "records nothing when refused or invalid", :aggregate_failures do
      expect { described_class.call(membership: owner, role: "member", actor: owner.user) }.not_to change(AuditEvent, :count)
      expect { described_class.call(membership: member, role: "admin", actor: owner.user) }.not_to change(AuditEvent, :count)
    end
  end
end
