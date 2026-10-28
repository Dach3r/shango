require "rails_helper"

RSpec.describe ThemePreview::Component, type: :component do
  it "renders a skeleton scoped to the palette with its radio", :aggregate_failures do
    form = ActionView::Helpers::FormBuilder.new(:membership, build(:membership), vc_test_controller.view_context, {})

    render_inline(described_class.new(form:, theme: :ocean))

    expect(page).to have_css("[data-palette=ocean]")
    expect(page).to have_css("input[type=radio][name='membership[theme]'][value=ocean]", visible: :all)
    expect(page).to have_text(I18n.t("projects.themes.edit.themes.ocean"))
  end

  it "tells the preview controller the scheme an Omarchy theme pins", :aggregate_failures do
    form = ActionView::Helpers::FormBuilder.new(:membership, build(:membership), vc_test_controller.view_context, {})

    render_inline(described_class.new(form:, theme: :vulkanite))

    expect(page).to have_css("input[value=vulkanite][data-scheme=dark]", visible: :all)
  end
end
