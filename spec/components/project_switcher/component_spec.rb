require "rails_helper"

RSpec.describe ProjectSwitcher::Component, type: :component do
  let(:current_project) { create(:project, name: "Alpha", icon: "bug") }
  let(:other_project) { create(:project, name: "Beta") }

  it "lists projects and marks the current one", :aggregate_failures do
    render_inline(described_class.new(current_project:, projects: [current_project, other_project]))

    expect(page).to have_css("button[aria-haspopup] span", text: "Alpha")
    expect(page).to have_css("button", text: "Beta", visible: :all)
    expect(page).to have_css("svg.text-accent", count: 1, visible: :all)
    expect(page).to have_link(I18n.t("components.project_switcher.new"), visible: :all)
  end
end
