require "rails_helper"

RSpec.describe Checkbox::Component, type: :component do
  let(:form) { ActionView::Helpers::FormBuilder.new(:variable, Variable.new, vc_test_controller.view_context, {}) }

  it "renders a labelled check box", :aggregate_failures do
    render_inline(described_class.new(form:, attribute: :secret, label: "Secret", class: "extra"))

    expect(page).to have_css("label", text: "Secret")
    expect(page).to have_css("input[type=checkbox][name='variable[secret]'].extra", visible: :all)
  end

  it "renders a plain param check box with an unchecked fallback", :aggregate_failures do
    render_inline(described_class.new(name: "a[b]", checked: true, label: "B", label_class: "text-sm", data: { field: "b" }))

    expect(page).to have_css("label.text-sm", text: "B")
    expect(page).to have_css("input[type=hidden][name='a[b]'][value='0']", visible: :all)
    expect(page).to have_css("input[type=checkbox][name='a[b]'][checked][data-field=b]", visible: :all)
  end
end
