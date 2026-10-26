class ThemePreview::Component < ApplicationComponent
  def initialize(form:, theme:)
    @form = form
    @theme = theme.to_s
  end

  private

  attr_reader :form, :theme
end
