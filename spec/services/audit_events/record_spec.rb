require "rails_helper"

RSpec.describe AuditEvents::Record do
  let(:project) { create(:project) }
  let(:actor) { create(:user, first_name: "Grace", last_name: "Hopper") }
  let(:target) { create(:user, first_name: "Alan", last_name: "Turing") }

  it "stores the event with the names of the people involved", :aggregate_failures do
    result = described_class.call(project:, kind: :role_changed, actor:, target:, from: "member", to: "owner")

    expect(result).to be_success
    expect(result.record).to have_attributes(project:, kind: "role_changed", actor:, target:)
    expect(result.record.metadata).to eq("actor_name" => "Grace Hopper", "target_name" => "Alan Turing", "from" => "member", "to" => "owner")
  end

  it "needs neither actor nor target", :aggregate_failures do
    event = described_class.call(project:, kind: :member_invited, email: "new@example.com").record

    expect(event.actor).to be_nil
    expect(event.metadata).to eq("email" => "new@example.com")
  end

  it "keeps the names after the accounts are gone", :aggregate_failures do
    event = described_class.call(project:, kind: :member_revoked, actor:, target:).record
    actor.destroy!
    event.reload

    expect(event.actor).to be_nil
    expect(event.actor_name).to eq("Grace Hopper")
  end

  it "refuses unknown kinds" do
    expect { described_class.call(project:, kind: :nonsense) }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
