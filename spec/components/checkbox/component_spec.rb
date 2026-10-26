require "rails_helper"

RSpec.describe Checkbox::Component, type: :component do
  let(:form) { ActionView::Helpers::FormBuilder.new(:variable, Variable.new, vc_test_controller.view_context, {}) }

  it "renders a labelled check box", :aggregate_failures do
    render_inline(described_class.new(form:, attribute: :secret, label: "Secret", class: "extra"))

    expect(page).to have_css("label", text: "Secret")
    expect(page).to have_css("input[type=checkbox][name='variable[secret]'].extra", visible: :all)
  end
end
