require "rails_helper"

RSpec.describe "Command palette", :system do
  let(:user) { create(:user) }
  let(:membership) { create(:membership, :owner, user:) }
  let(:project) { membership.project }

  before do
    user.update!(current_membership: membership)
    login_as user, scope: :user
  end

  it "opens with Ctrl+K, filters as you type and follows the selected result with Enter", :aggregate_failures do
    create(:api_request, collection: create(:collection, project:), name: "List invoices")
    visit overview_path
    find("body").send_keys([:control, "k"])

    expect(page).to have_css("dialog[open] a[role=option]", text: I18n.t("components.tools_nav.monitoring"))

    fill_in I18n.t("layouts.app.palette.placeholder"), with: "invoices"

    expect(page).to have_css("a[role=option][aria-selected=true]", text: "List invoices")
    find_field(I18n.t("layouts.app.palette.placeholder")).send_keys(:enter)

    expect(page).to have_current_path(%r{\A/workbench/requests/})
  end

  it "opens from the status bar button and moves the selection with the arrows", :aggregate_failures do
    visit overview_path
    find("button[aria-label='#{I18n.t("components.status_bar.search")}']").click

    expect(page).to have_css("a[role=option][aria-selected=true]", text: I18n.t("components.tools_nav.overview"))

    find_field(I18n.t("layouts.app.palette.placeholder")).send_keys(:down)

    expect(page).to have_css("a[role=option][aria-selected=true]", text: I18n.t("components.tools_nav.api_client"))
  end
end
