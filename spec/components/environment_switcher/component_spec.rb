require "rails_helper"

RSpec.describe EnvironmentSwitcher::Component, type: :component do
  let(:project) { create(:project) }
  let(:staging) { create(:environment, project:, name: "Staging") }
  let(:production) { create(:environment, project:, name: "Production") }

  context "without a current environment" do
    it "shows the none label and lists environments", :aggregate_failures do
      render_inline(described_class.new(environments: [staging, production], current_environment: nil))

      expect(page).to have_css("button[aria-haspopup]", text: I18n.t("components.environment_switcher.none"))
      expect(page).to have_css("li button", text: "Staging", visible: :all)
      expect(page).to have_css("li svg.text-accent", count: 1, visible: :all)
    end
  end

  context "with a current environment" do
    it "shows its name and marks it", :aggregate_failures do
      render_inline(described_class.new(environments: [staging, production], current_environment: staging))

      expect(page).to have_css("button[aria-haspopup] span.truncate", text: "Staging")
      expect(page).to have_css("button", text: "Staging", visible: :all)
      expect(page).to have_css("li svg.text-accent", count: 1, visible: :all)
    end
  end
end
