require "rails_helper"

RSpec.describe Topbar::Component, type: :component do
  it "renders the project switcher", :aggregate_failures do
    project = create(:project, name: "Alpha")
    render_inline(described_class.new(current_project: project, projects: [project]))

    expect(page).to have_css("header button[title=Alpha]")
    expect(page).to have_no_text(I18n.t("components.tools_nav.title"))
  end
end
