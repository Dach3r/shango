require "rails_helper"

RSpec.describe AuditEventsHelper do
  let(:project) { create(:project) }
  let(:actor) { create(:user, first_name: "Grace", last_name: "Hopper") }
  let(:target) { create(:user, first_name: "Alan", last_name: "Turing") }

  it "reads as a sentence about the people involved", :aggregate_failures do
    expect(helper.audit_event_summary(create(:audit_event, project:, actor:, target:, kind: "member_revoked"))).to eq("Grace Hopper removed Alan Turing.")
    expect(helper.audit_event_summary(create(:audit_event, project:, actor:, kind: "member_left"))).to eq("Grace Hopper left the project.")
  end

  it "names roles and emails from the metadata", :aggregate_failures do
    changed = create(:audit_event, project:, actor:, target:, kind: "role_changed", metadata: { "from" => "member", "to" => "owner" })
    invited = create(:audit_event, project:, actor:, kind: "member_invited", metadata: { "email" => "new@example.com", "role" => "member" })

    expect(helper.audit_event_summary(changed)).to eq("Grace Hopper changed the role of Alan Turing from Member to Owner.")
    expect(helper.audit_event_summary(invited)).to eq("Grace Hopper invited new@example.com (Member).")
  end

  it "stands in for people whose accounts are gone" do
    event = create(:audit_event, project:, actor: nil, target: nil, kind: "member_revoked")

    expect(helper.audit_event_summary(event)).to eq("a former member removed a former member.")
  end
end
