require "rails_helper"

RSpec.describe Invitation do
  subject(:invitation) { create(:invitation, email: "  New.Person@Example.com ") }

  it { is_expected.to belong_to(:project) }
  it { is_expected.to belong_to(:inviter).optional }
  it { is_expected.to define_enum_for(:role).with_values(member: "member", owner: "owner").backed_by_column_of_type(:string) }

  it "normalizes the email" do
    expect(invitation.email).to eq("new.person@example.com")
  end

  it "needs a well formed email", :aggregate_failures do
    expect(build(:invitation, email: "")).not_to be_valid
    expect(build(:invitation, email: "not an email")).not_to be_valid
  end

  it "rejects unknown roles" do
    expect(build(:invitation, role: "admin")).not_to be_valid
  end

  it "caps the email length at the address limit", :aggregate_failures do
    expect(build(:invitation, email: "#{"x" * 242}@example.com")).to be_valid
    expect(build(:invitation, email: "#{"x" * 243}@example.com")).not_to be_valid
  end

  describe "the token" do
    it "is known only when created and stored as a digest", :aggregate_failures do
      expect(invitation.token).to be_present
      expect(invitation.token_digest).to eq(described_class.digest(invitation.token))
      expect(invitation.token_digest).not_to include(invitation.token)
      expect(described_class.find(invitation.id).token).to be_nil
    end

    it "finds the invitation", :aggregate_failures do
      expect(described_class.find_by_token(invitation.token)).to eq(invitation)
      expect(described_class.find_by_token("wrong")).to be_nil
      expect(described_class.find_by_token("")).to be_nil
      expect(described_class.find_by_token(nil)).to be_nil
    end

    it "is different for every invitation" do
      expect(create(:invitation).token).not_to eq(invitation.token)
    end
  end

  describe "validity" do
    it "lasts a week", :aggregate_failures do
      expect(invitation.expires_at).to be_within(1.minute).of(7.days.from_now)
      expect(invitation).to be_usable
    end

    it "stops being usable once expired, accepted or revoked", :aggregate_failures do
      expect(create(:invitation, :expired)).not_to be_usable
      expect(create(:invitation, :accepted)).to be_accepted
      expect(create(:invitation, :accepted)).not_to be_usable
      expect(create(:invitation, :revoked)).to be_revoked
      expect(create(:invitation, :revoked)).not_to be_usable
    end

    it "keeps an explicit expiry" do
      expect(create(:invitation, expires_at: 1.hour.from_now).expires_at).to be_within(1.second).of(1.hour.from_now)
    end
  end

  describe ".open" do
    it "leaves out accepted and revoked invitations" do
      open = create(:invitation)
      expired = create(:invitation, :expired)
      create(:invitation, :accepted)
      create(:invitation, :revoked)

      expect(described_class.open).to contain_exactly(open, expired)
    end
  end

  describe "database constraints" do
    it "allows one open invitation per project and email", :aggregate_failures do
      project = create(:project)
      create(:invitation, project:, email: "a@example.com")

      expect { create(:invitation, project:, email: "a@example.com") }.to raise_error(ActiveRecord::RecordNotUnique)
      expect { create(:invitation, :revoked, project:, email: "a@example.com") }.not_to raise_error
    end

    it "rejects unknown roles" do
      invitation.role = "member"
      expect { invitation.update_column(:role, "admin") }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end
end
