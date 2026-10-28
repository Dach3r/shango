require "rails_helper"

RSpec.describe Projects::Invitations::Create do
  let(:project) { create(:project) }
  let(:inviter) { create(:user) }

  def call(email: "New@Example.com", role: "member")
    described_class.call(project:, inviter:, email:, role:)
  end

  before { ActionMailer::Base.deliveries.clear }

  it "creates the invitation for the normalized email", :aggregate_failures do
    result = call

    expect(result).to be_success
    expect(result.record).to have_attributes(project:, inviter:, email: "new@example.com", role: "member")
    expect(result.record.token).to be_present
  end

  it "does not send email without SMTP", :aggregate_failures do
    result = call

    expect(result.data[:delivered]).to be(false)
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  context "with SMTP configured" do
    before { stub_const("ENV", ENV.to_h.merge("SHANGO_SMTP_ADDRESS" => "smtp.example.com")) }

    it "emails the link", :aggregate_failures do
      result = call
      mail = ActionMailer::Base.deliveries.last

      expect(result.data[:delivered]).to be(true)
      expect(mail.to).to eq(["new@example.com"])
      expect(mail.subject).to eq(I18n.t("invitation_mailer.invite.subject", project: project.name))
      expect(mail.body.encoded).to include("token=#{result.record.token}")
    end

    it "still creates the invitation when the email cannot be delivered", :aggregate_failures do
      allow(InvitationMailer).to receive(:invite).and_raise(Errno::ECONNREFUSED)
      result = call

      expect(result).to be_success
      expect(result.data[:delivered]).to be(false)
      expect(Invitation.count).to eq(1)
    end
  end

  it "replaces the open invitation for the same address", :aggregate_failures do
    first = call.record
    second = call(role: "owner").record

    expect(first.reload).to be_revoked
    expect(second).not_to be_revoked
    expect(project.invitations.open).to contain_exactly(second)
  end

  it "keeps invitations of other projects" do
    other = create(:invitation, email: "new@example.com")
    call

    expect(other.reload).not_to be_revoked
  end

  it "rejects malformed emails and unknown roles", :aggregate_failures do
    expect(call(email: "nope").error).to eq(:invalid)
    expect(call(role: "admin").error).to eq(:invalid)
    expect(Invitation.count).to eq(0)
  end

  it "does not invite people who already belong to the project", :aggregate_failures do
    member = create(:membership, project:, user: create(:user, email: "member@example.com"))

    expect(call(email: "Member@example.com").error).to eq(:already_member)
    expect(member).to be_active
  end

  it "invites people whose membership was revoked" do
    create(:membership, :revoked, project:, user: create(:user, email: "gone@example.com"))

    expect(call(email: "gone@example.com")).to be_success
  end

  it "reports a concurrent duplicate" do
    allow_any_instance_of(Invitation).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique) # rubocop:disable RSpec/AnyInstance

    expect(call.error).to eq(:duplicate)
  end

  it "records the invitation", :aggregate_failures do
    call(role: "owner")

    expect(AuditEvent.last).to have_attributes(project:, kind: "member_invited", actor: inviter, metadata: include("email" => "new@example.com", "role" => "owner"))
  end

  it "records nothing when refused" do
    expect { call(email: "nope") }.not_to change(AuditEvent, :count)
  end
end
