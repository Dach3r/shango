class Modal::Component < ApplicationComponent
  include ControlsHelper

  SIZES = { sm: "max-w-md", md: "max-w-lg", lg: "max-w-2xl", xl: "max-w-4xl" }.freeze

  renders_one :footer

  # title/description/icon fill the header. `submit` (label, with `submit_icon`) renders the default footer with Cancel + a submit button
  # tied to the form with id `form`; pass a `footer` slot instead for custom actions, or neither for no footer.
  def initialize(title:, description: nil, icon: nil, size: :md, form: nil, submit: nil, submit_icon: "check", cancel: true, dismissible: true, centered: false)
    @title = title
    @description = description
    @icon = icon
    @size = size
    @form = form
    @submit = submit
    @submit_icon = submit_icon
    @cancel = cancel
    @dismissible = dismissible
    @centered = centered
  end

  private

  def size_class
    SIZES.fetch(@size)
  end

  def show_footer?
    footer? || @submit.present?
  end
end
