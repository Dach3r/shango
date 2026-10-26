require "rails_helper"

RSpec.describe RequestTabs::Component, type: :component do
  let(:project) { create(:project) }
  let(:user) { create(:user) }

  it "renders only the new draft button without requests", :aggregate_failures do
    render_inline(described_class.new(requests: []))

    expect(page).to have_button(I18n.t("components.request_tabs.new_draft"))
    expect(page).to have_no_link
  end

  it "renders the given content after the tabs" do
    render_inline(described_class.new(requests: [])) { "Actions" }

    expect(page).to have_text("Actions")
  end

  it "renders a tab per request and marks the open one", :aggregate_failures do
    first = ApiClient::Requests::CreateDraft.call(project:, user:).record.tap { |r| r.update!(name: "First") }
    saved = create(:api_request, project:, name: "Saved")

    render_inline(described_class.new(requests: [first, saved], current_request_id: saved.id))

    expect(page).to have_link("First", href: "/workbench/requests/#{first.id}")
    expect(page).to have_css("a[aria-current=page]", text: "Saved")
    expect(page).to have_no_css("a[aria-current=page]", text: "First")
    expect(page).to have_link(I18n.t("components.request_tabs.close", name: "First"), href: "/workbench/requests/#{first.id}/closure/new")
  end

  it "closes saved requests without a confirmation", :aggregate_failures do
    saved = create(:api_request, project:, name: "Saved")
    other = create(:api_request, project:, name: "Other")

    render_inline(described_class.new(requests: [saved, other], current_request_id: saved.id))

    expect(page).to have_css("form[action='/workbench/requests/#{saved.id}/tab?current=true']")
    expect(page).to have_css("form[action='/workbench/requests/#{other.id}/tab']")
  end
end
