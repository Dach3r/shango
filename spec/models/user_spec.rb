require "rails_helper"

RSpec.describe User do
  subject(:user) { build(:user) }

  it { is_expected.to validate_presence_of(:first_name) }
  it { is_expected.to validate_presence_of(:last_name) }

  describe "password confirmation" do
    let(:persisted_user) { create(:user) }

    it "is required when a persisted user sets a password", :aggregate_failures do
      persisted_user.password = "newpassword1"
      persisted_user.password_confirmation = ""

      expect(persisted_user).not_to be_valid
      expect(persisted_user.errors).to include(:password_confirmation)
    end

    it "is not required when the password is untouched" do
      expect(persisted_user.update(first_name: "Grace")).to be(true)
    end
  end

  describe "email confirmation" do
    it "does not wait for confirmation without SMTP", :aggregate_failures do
      created = create(:user)

      expect(created.active_for_authentication?).to be(true)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "waits for confirmation when it is enforced", :aggregate_failures do
      allow(Shango::Mailing).to receive(:confirmation_required?).and_return(true)
      created = create(:user)

      expect(created.active_for_authentication?).to be(false)
      expect(ActionMailer::Base.deliveries.last.to).to eq([created.email])
    end

    it "lets confirmed users in when it is enforced" do
      allow(Shango::Mailing).to receive(:confirmation_required?).and_return(true)

      expect(create(:user, :confirmed).active_for_authentication?).to be(true)
    end

    it "postpones email changes only when it is enforced", :aggregate_failures do
      allow(Shango::Mailing).to receive(:confirmation_required?).and_return(true)
      confirmed = create(:user, :confirmed)
      confirmed.update!(email: "new@example.com")

      expect(confirmed.reload).to have_attributes(unconfirmed_email: "new@example.com")
      expect(confirmed.email).not_to eq("new@example.com")
    end
  end

  describe "account locking" do
    it "locks the account after too many failed attempts", :aggregate_failures do
      locked = create(:user)
      User.maximum_attempts.times { locked.valid_for_authentication? { false } }

      expect(locked.reload.access_locked?).to be(true)
      expect(locked.active_for_authentication?).to be(false)
    end
  end

  describe "#full_name" do
    it "joins first and last name" do
      expect(user.full_name).to eq("Ada Lovelace")
    end
  end

  describe "#initials" do
    it "returns uppercase initials" do
      user.first_name = "ada"
      user.last_name = "lovelace"

      expect(user.initials).to eq("AL")
    end
  end

  describe "#available_memberships" do
    let(:saved_user) { create(:user) }
    let(:active_membership) { create(:membership, user: saved_user) }
    let(:revoked_membership) { create(:membership, :revoked, user: saved_user) }
    let(:archived_membership) { create(:membership, user: saved_user, project: create(:project, :archived)) }

    it "includes only active memberships of active projects" do
      active_membership
      revoked_membership
      archived_membership

      expect(saved_user.available_memberships).to contain_exactly(active_membership)
    end
  end

  describe "#projects" do
    let(:saved_user) { create(:user) }
    let(:active_membership) { create(:membership, user: saved_user) }

    it "excludes revoked memberships", :aggregate_failures do
      create(:membership, :revoked, user: saved_user)

      expect(saved_user.projects).to be_empty
      expect(active_membership.project.users).to contain_exactly(saved_user)
    end
  end
end
