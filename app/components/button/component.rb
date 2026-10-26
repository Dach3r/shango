class Button::Component < ApplicationComponent
  BASE = "flex #{CONTROL_SIZE} w-full cursor-pointer items-center justify-center gap-2 rounded-xl text-center text-base font-medium transition focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-card"
  VARIANTS = {
    primary: "bg-solid text-on-solid shadow-sm shadow-brand-700/20 hover:bg-solid-hover focus:ring-solid/50",
    secondary: "bg-ink/[0.03] text-ink ring-1 ring-inset ring-line hover:bg-accent/10 hover:text-accent hover:ring-accent focus:ring-solid/50"
  }.freeze

  def initialize(label:, icon: nil, form: nil, href: nil, variant: :primary, **options)
    @form = form
    @label = label
    @icon = icon
    @href = href
    @variant = variant
    @options = options
  end

  def call
    if @href
      link_to content_with_icon, @href, **@options, class: classes
    else
      @form.button content_with_icon, type: :submit, **@options, class: classes
    end
  end

  private

  def content_with_icon
    safe_join([(helpers.lucide_icon(@icon, class: "size-4 shrink-0") if @icon), @label])
  end

  def classes
    class_names(BASE, VARIANTS.fetch(@variant), @options[:class])
  end
end
