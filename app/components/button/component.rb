class Button::Component < ApplicationComponent
  BASE = "w-full cursor-pointer rounded-xl py-3.5 text-base font-semibold shadow-sm shadow-brand-700/20 transition focus:outline-none focus:ring-2 focus:ring-offset-2"
  VARIANTS = {
    primary: "bg-brand-500 text-white hover:bg-brand-600 focus:ring-brand-500/40"
  }.freeze

  def initialize(form:, label:, variant: :primary, **options)
    @form = form
    @label = label
    @variant = variant
    @options = options
  end

  def call
    @form.submit @label, **@options, class: class_names(BASE, VARIANTS.fetch(@variant), @options[:class])
  end
end
