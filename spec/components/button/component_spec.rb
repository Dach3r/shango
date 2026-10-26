require "rails_helper"

RSpec.describe Button::Component, type: :component do
  let(:form) { ActionView::Helpers::FormBuilder.new(:user, User.new, vc_test_controller.view_context, {}) }

  context "with an href" do
    it "renders a link with the primary variant by default", :aggregate_failures do
      render_inline(described_class.new(label: "Go", icon: "log-in", href: "/x", class: "extra"))

      expect(page).to have_link("Go", href: "/x", class: %w[bg-solid extra])
      expect(page).to have_css("a > svg:first-child")
    end
  end

  context "without an href" do
    it "renders a submit button with the given variant", :aggregate_failures do
      render_inline(described_class.new(label: "Save", icon: "save", form:, variant: :secondary))

      expect(page).to have_button("Save", class: "text-ink", type: "submit")
      expect(page).to have_css("button > svg:first-child")
      expect(page).to have_no_css("button.bg-solid")
    end
  end
end
