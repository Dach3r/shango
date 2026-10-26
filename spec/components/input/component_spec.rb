require "rails_helper"

RSpec.describe Input::Component, type: :component do
  let(:form) { ActionView::Helpers::FormBuilder.new(:user, User.new, vc_test_controller.view_context, {}) }

  def render_input(**options)
    render_inline(described_class.new(form:, attribute: :email, label: "Email", **options))
  end

  it "renders a text field with the default icon for its type", :aggregate_failures do
    render_input(type: :email, placeholder: "you@example.com")

    expect(page).to have_css("label", text: "Email")
    expect(page).to have_css("input[type=email][name='user[email]'][placeholder='you@example.com'].pl-11")
    expect(page).to have_css("span.absolute svg")
  end

  it "renders no icon when none applies", :aggregate_failures do
    render_input

    expect(page).to have_css("input[type=text]")
    expect(page).to have_no_css("svg")
  end

  it "renders a text area without the control height", :aggregate_failures do
    render_input(type: :text_area, class: "extra")

    expect(page).to have_css("textarea.min-h-28.extra")
    expect(page).to have_no_css("textarea.h-14")
  end

  it "renders a password field with a visibility toggle", :aggregate_failures do
    render_input(type: :password, data: { foo: "bar" })

    expect(page).to have_css("input[type=password][data-password-visibility-target=input][data-foo=bar].pr-12")
    expect(page).to have_css("button[data-action='password-visibility#toggle']")
  end

  it "keeps the password toggle target when no data is given" do
    render_input(type: :password)

    expect(page).to have_css("[data-controller=password-visibility] input[data-password-visibility-target=input]")
  end
end
