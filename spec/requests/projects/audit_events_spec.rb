require "rails_helper"

RSpec.describe "Team activity" do
  let!(:context) { sign_in_with_project }
  let(:user) { context[0] }
  let(:project) { context[1] }

  def event(attributes = {})
    create(:audit_event, project:, actor: user, kind: "member_left", **attributes)
  end

  describe "GET /audit_events" do
    it "lists the team history, newest first", :aggregate_failures do
      event(created_at: 2.days.ago, kind: "member_invited", metadata: { "email" => "old@example.com", "role" => "member" })
      event(created_at: 1.hour.ago, kind: "member_revoked", target: create(:user, first_name: "Grace", last_name: "Hopper"))
      get audit_events_path

      expect(response.body).to include("Ada Lovelace removed Grace Hopper.", "Ada Lovelace invited old@example.com as Member.")
      expect(response.body.index("Grace Hopper")).to be < response.body.index("old@example.com")
    end

    it "keeps other projects' history out" do
      create(:audit_event, kind: "member_invited", metadata: { "email" => "elsewhere@example.com", "role" => "member" })
      get audit_events_path

      expect(response.body).not_to include("elsewhere@example.com")
    end

    it "says so when nothing happened yet" do
      get audit_events_path

      expect(response.body).to include(I18n.t("projects.audit_events.index.empty"))
    end

    it "pages through long histories", :aggregate_failures do
      (Projects::AuditEventsController::PER_PAGE + 1).times { |index| event(created_at: index.minutes.ago, metadata: { "actor_name" => "x" }) }
      get audit_events_path

      expect(response.body).to include(I18n.t("projects.audit_events.index.older"))
      expect(response.body).not_to include(I18n.t("projects.audit_events.index.newer"))

      get audit_events_path(page: 2)
      expect(response.body).to include(I18n.t("projects.audit_events.index.newer"))
      expect(response.body).not_to include(I18n.t("projects.audit_events.index.older"))
      expect(response.body.scan(I18n.t("projects.audit_events.index.kinds.member_left", actor: "Ada Lovelace")).size).to eq(1)
    end

    it "links the first page back without a page parameter" do
      (Projects::AuditEventsController::PER_PAGE + 1).times { |index| event(created_at: index.minutes.ago) }
      get audit_events_path(page: 2)

      expect(response.body).to include(%(href="#{audit_events_path}"))
    end

    it "treats invalid pages as the first one" do
      event
      get audit_events_path(page: "-3")

      expect(response.body).to include("Ada Lovelace left the project.")
    end

    it "is owner-only", :aggregate_failures do
      member = create(:user)
      membership = create(:membership, project:, user: member)
      member.update!(current_membership: membership)
      sign_in member
      get audit_events_path

      expect(response).to redirect_to(workbench_root_path)
      expect(flash[:alert]).to eq(I18n.t("authorization.forbidden"))
    end
  end

  describe "the trail left by the team screens" do
    let!(:member_membership) { create(:membership, project:, user: create(:user, first_name: "Grace", last_name: "Hopper")) }

    it "records role changes, removals and invitations", :aggregate_failures do
      patch member_path(member_membership), params: { member: { role: "owner" } }
      post invitations_path, params: { invitation: { email: "new@example.com", role: "member" } }
      delete member_path(member_membership)

      expect(project.audit_events.recent.map(&:kind)).to eq(%w[member_revoked member_invited role_changed])
    end

    it "links to the activity from the members page for owners" do
      get members_path

      expect(response.body).to include(%(href="#{audit_events_path}"))
    end

    it "does not link to it for members" do
      sign_in member_membership.user
      member_membership.user.update!(current_membership: member_membership)
      get members_path

      expect(response.body).not_to include(%(href="#{audit_events_path}"))
    end
  end
end
