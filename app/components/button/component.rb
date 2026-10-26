class Button::Component < ApplicationComponent
  BASE = "flex #{CONTROL_SIZE} w-full cursor-pointer items-center justify-center rounded-xl text-center text-base font-semibold transition focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-card"
  VARIANTS = {
    primary: "bg-solid text-on-solid shadow-sm shadow-brand-700/20 hover:bg-solid-hover focus:ring-solid/50",
    secondary: "bg-ink/[0.03] text-ink ring-1 ring-inset ring-line hover:bg-accent/10 hover:text-accent hover:ring-accent focus:ring-solid/50"
  }.freeze

  def initialize(label:, form: nil, href: nil, variant: :primary, **options)
    @form = form
    @label = label
    @href = href
    @variant = variant
    @options = options
  end

  def call
    if @href
      link_to @label, @href, **@options, class: classes
    else
      @form.submit @label, **@options, class: classes
    end
  end

  private

  def classes
    class_names(BASE, VARIANTS.fetch(@variant), @options[:class])
  end
end
