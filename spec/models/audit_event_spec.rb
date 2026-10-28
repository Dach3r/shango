require "rails_helper"

RSpec.describe AuditEvent do
  it { is_expected.to belong_to(:project) }
  it { is_expected.to belong_to(:actor).optional }
  it { is_expected.to belong_to(:target).optional }

  it "knows the kinds of event" do
    expect(described_class.kinds.keys).to eq(%w[member_invited invitation_accepted invitation_revoked role_changed member_revoked member_left ownership_transferred])
  end

  it "rejects unknown kinds", :aggregate_failures do
    event = build(:audit_event, kind: "x")

    expect(event).not_to be_valid
    expect { event.kind = "x" }.not_to raise_error
  end

  it "lists the latest first" do
    old = create(:audit_event, created_at: 2.days.ago)
    recent = create(:audit_event, created_at: 1.hour.ago)

    expect(described_class.recent).to eq([recent, old])
  end

  describe "names" do
    let(:actor) { create(:user, first_name: "Grace", last_name: "Hopper") }
    let(:target) { create(:user, first_name: "Alan", last_name: "Turing") }

    it "come from the users while they exist", :aggregate_failures do
      event = create(:audit_event, actor:, target:)

      expect(event.actor_name).to eq("Grace Hopper")
      expect(event.target_name).to eq("Alan Turing")
    end

    it "fall back to the copy kept in the metadata once the users are gone", :aggregate_failures do
      event = create(:audit_event, actor:, target:, metadata: { "actor_name" => "Grace Hopper", "target_name" => "Alan Turing" })
      actor.destroy!
      target.destroy!
      event.reload

      expect(event.actor_name).to eq("Grace Hopper")
      expect(event.target_name).to eq("Alan Turing")
    end

    it "show the invited email when there is no target" do
      expect(create(:audit_event, kind: "member_invited", metadata: { "email" => "new@example.com" }).target_name).to eq("new@example.com")
    end
  end

  it "has a database constraint on the kind" do
    event = create(:audit_event)

    expect { event.update_column(:kind, "x") }.to raise_error(ActiveRecord::StatementInvalid)
  end
end
