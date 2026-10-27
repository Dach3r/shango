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

  it "marks a saved tab that keeps unsaved edits", :aggregate_failures do
    saved = create(:api_request, project:, name: "Saved")
    other = create(:api_request, project:, name: "Other")

    render_inline(described_class.new(requests: [saved, other], unsaved_ids: [saved.id]))

    expect(page).to have_css("[title='#{I18n.t("components.request_tabs.unsaved_hint")}']", count: 1)
  end

  it "wires the close shortcut to each tab's close control", :aggregate_failures do
    saved = create(:api_request, project:, name: "Saved")

    render_inline(described_class.new(requests: [saved], current_request_id: saved.id))

    expect(page).to have_css("nav[data-action='keydown@window->request-tabs#closeCurrent']")
    expect(page).to have_css("[data-request-tab] [data-request-tab-close]")
  end

  it "closes saved requests without a confirmation", :aggregate_failures do
    saved = create(:api_request, project:, name: "Saved")
    other = create(:api_request, project:, name: "Other")

    render_inline(described_class.new(requests: [saved, other], current_request_id: saved.id))

    expect(page).to have_css("form[action='/workbench/requests/#{saved.id}/tab?current=true']")
    expect(page).to have_css("form[action='/workbench/requests/#{other.id}/tab']")
  end

  it "asks before closing a saved tab with unsaved edits and flags it for bulk closes", :aggregate_failures do
    saved = create(:api_request, project:, name: "Saved")
    other = create(:api_request, project:, name: "Other")
    message = I18n.t("components.request_tabs.confirm_close", name: "Saved")

    render_inline(described_class.new(requests: [saved, other], unsaved_ids: [saved.id]))

    expect(page).to have_css("form[action='/workbench/requests/#{saved.id}/tab'][data-turbo-confirm='#{message}']")
    expect(page).to have_no_css("form[action='/workbench/requests/#{other.id}/tab'][data-turbo-confirm]")
    expect(page).to have_css("[data-request-tab-id='#{saved.id}'][data-confirm-message='#{message}']", visible: :all)
    expect(page).to have_no_css("[data-request-tab-id='#{other.id}'][data-confirm-message]", visible: :all)
  end

  it "flags drafts with edits but not untouched ones for the bulk close confirmation", :aggregate_failures do
    untouched = ApiClient::Requests::CreateDraft.call(project:, user:).record
    edited = ApiClient::Requests::CreateDraft.call(project:, user:).record
    edited.update!(name: "Edited")

    render_inline(described_class.new(requests: [untouched, edited.reload]))

    expect(page).to have_css("[data-request-tab-id='#{edited.id}'][data-confirm-message]", visible: :all)
    expect(page).to have_no_css("[data-request-tab-id='#{untouched.id}'][data-confirm-message]", visible: :all)
  end

  it "closes untouched drafts without a confirmation", :aggregate_failures do
    draft = ApiClient::Requests::CreateDraft.call(project:, user:).record

    render_inline(described_class.new(requests: [draft]))

    expect(page).to have_css("form[action='/workbench/requests/#{draft.id}'] input[name=_method][value=delete]", visible: :all)
    expect(page).to have_no_link(href: "/workbench/requests/#{draft.id}/closure/new")
  end

  it "marks drafts with a dot and leaves saved requests without one", :aggregate_failures do
    draft = ApiClient::Requests::CreateDraft.call(project:, user:).record
    saved = create(:api_request, collection: create(:collection, project:))

    render_inline(described_class.new(requests: [draft, saved]))

    expect(page).to have_css("[title='#{I18n.t("components.request_tabs.draft_hint")}']", count: 1)
  end

  it "renders a context menu per tab with the close options disabled at the edges", :aggregate_failures do
    first = create(:api_request, project:, name: "First")
    last = create(:api_request, project:, name: "Last")

    render_inline(described_class.new(requests: [first, last], current_request_id: last.id))

    menus = page.all("[data-request-tab]", visible: :all)
    expect(menus.first).to have_css("form[action^='/workbench/tabs?'] button[disabled]", visible: :all, count: 1)
    expect(menus.last).to have_css("form[action*='side=right'] button[disabled]", visible: :all)
    expect(menus.first).to have_css("form[action*='side=all'][action*='current=#{last.id}']", visible: :all)
    expect(menus.first).to have_css("form[action='/workbench/requests/#{first.id}/duplication']", visible: :all)
  end
end
