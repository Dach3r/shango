require "rails_helper"

RSpec.describe Topbar::Component, type: :component do
  let(:project) { create(:project, name: "Alpha") }

  def render_topbar(path: "/workbench", controller_path: "workbench/workspaces", **options)
    allow(vc_test_controller).to receive(:controller_path).and_return(controller_path)
    with_request_url(path) { render_inline(described_class.new(current_project: project, projects: [project], user: create(:user, first_name: "Ada", last_name: "Lovelace"), **options)) }
  end

  it "highlights the api client on the workbench root", :aggregate_failures do
    render_topbar

    expect(page).to have_css("a[aria-current=page]", text: I18n.t("components.topbar.api_client"))
    expect(page).to have_css("span[aria-disabled=true]", text: I18n.t("components.topbar.monitoring"))
  end

  it "highlights a feature on any of its controllers" do
    render_topbar(path: "/workbench/requests/1", controller_path: "workbench/requests")

    expect(page).to have_css("a[aria-current=page]", text: I18n.t("components.topbar.api_client"))
  end

  it "highlights nothing on unrelated pages" do
    render_topbar(path: "/projects/new", controller_path: "projects")

    expect(page).to have_no_css("a[aria-current=page]")
  end

  it "separates live tools from upcoming ones", :aggregate_failures do
    render_topbar

    expect(page).to have_css("ul:first-of-type a", text: I18n.t("components.topbar.api_client"))
    expect(page).to have_css("ul:last-of-type span[aria-disabled=true]", text: I18n.t("components.topbar.logs"))
  end

  it "renders the user menu at the end of the bar" do
    render_topbar

    expect(page).to have_text("Ada Lovelace")
  end
end
