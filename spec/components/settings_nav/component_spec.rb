require "rails_helper"

RSpec.describe SettingsNav::Component, type: :component do
  let(:project) { create(:project, name: "Alpha") }

  def render_nav(controller_path: "projects/memberships")
    allow(vc_test_controller).to receive(:controller_path).and_return(controller_path)
    with_request_url("/membership/settings") { render_inline(described_class.new(project:)) }
  end

  it "groups the sections by scope", :aggregate_failures do
    render_nav

    expect(page).to have_css("h2", text: I18n.t("components.settings_nav.groups.account"))
    expect(page).to have_css("h2", text: I18n.t("components.settings_nav.groups.membership", project: "Alpha"))
    expect(page).to have_css("h2", text: I18n.t("components.settings_nav.groups.project"))
  end

  it "highlights the live section on its controller", :aggregate_failures do
    render_nav

    expect(page).to have_css("a[aria-current=page][href='/membership/settings']", text: I18n.t("components.settings_nav.items.sidebar"))
    expect(page).to have_css("span[aria-disabled=true]", text: I18n.t("components.settings_nav.items.members"))
  end

  it "highlights nothing on other controllers" do
    render_nav(controller_path: "projects")

    expect(page).to have_no_css("a[aria-current=page]")
  end
end
