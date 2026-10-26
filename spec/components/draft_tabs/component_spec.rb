require "rails_helper"

RSpec.describe DraftTabs::Component, type: :component do
  let(:project) { create(:project) }
  let(:user) { create(:user) }

  it "renders only the new draft button without drafts" do
    render_inline(described_class.new(drafts: []))

    expect(page).to have_button(I18n.t("components.draft_tabs.new_draft"))
    expect(page).to have_no_link
  end

  it "renders a tab per draft and marks the open one", :aggregate_failures do
    first = ApiClient::Requests::CreateDraft.call(project:, user:).record.tap { |r| r.update!(name: "First") }
    second = ApiClient::Requests::CreateDraft.call(project:, user:).record.tap { |r| r.update!(name: "Second") }

    render_inline(described_class.new(drafts: [first, second], current_request_id: second.id))

    expect(page).to have_link("First", href: "/workbench/requests/#{first.id}")
    expect(page).to have_css("a[aria-current=page]", text: "Second")
    expect(page).to have_no_css("a[aria-current=page]", text: "First")
    expect(page).to have_link(I18n.t("components.draft_tabs.close", name: "First"), href: "/workbench/requests/#{first.id}/closure/new")
  end
end
