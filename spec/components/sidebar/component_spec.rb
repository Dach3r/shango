require "rails_helper"

RSpec.describe Sidebar::Component, type: :component do
  let(:project) { create(:project, name: "Alpha") }

  def render_sidebar(path: "/workbench", controller_path: "workbench/workspaces")
    allow(vc_test_controller).to receive(:controller_path).and_return(controller_path)
    with_request_url(path) { render_inline(described_class.new(current_project: project, projects: [project], user: create(:user, first_name: "Ada", last_name: "Lovelace"))) }
  end

  it "highlights the api client on the workbench root", :aggregate_failures do
    render_sidebar

    expect(page).to have_css("a[aria-current=page]", text: I18n.t("components.sidebar.api_client"))
    expect(page).to have_css("span[aria-disabled=true]", text: I18n.t("components.sidebar.monitoring"))
  end

  it "highlights a feature on any of its controllers" do
    render_sidebar(path: "/workbench/requests/1", controller_path: "workbench/requests")

    expect(page).to have_css("a[aria-current=page]", text: I18n.t("components.sidebar.api_client"))
  end

  it "links settings and highlights them on the membership screen", :aggregate_failures do
    render_sidebar(path: "/membership/edit", controller_path: "projects/memberships")

    expect(page).to have_css("a[aria-current=page][href='/membership/edit']", text: I18n.t("components.sidebar.settings"))
  end

  it "highlights nothing on unrelated pages" do
    render_sidebar(path: "/projects/new", controller_path: "projects")

    expect(page).to have_no_css("a[aria-current=page]")
  end

  it "renders the user menu in the footer" do
    render_sidebar

    expect(page).to have_text("Ada Lovelace")
  end
end
