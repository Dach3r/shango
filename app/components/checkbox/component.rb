class Checkbox::Component < ApplicationComponent
  BOX = "peer size-5 cursor-pointer appearance-none rounded-md border border-line bg-field transition hover:border-accent/60 checked:border-solid checked:bg-solid focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-accent/25"
  LABEL = "flex cursor-pointer items-center gap-2.5 text-body"
  ICON = "pointer-events-none absolute inset-0 m-auto size-3.5 stroke-[3] text-on-solid opacity-0 transition peer-checked:opacity-100"

  def initialize(form:, attribute:, label:, **options)
    @form = form
    @attribute = attribute
    @label = label
    @options = options
  end

  private

  def label_classes
    LABEL
  end

  def icon_classes
    ICON
  end

  def field
    @form.check_box @attribute, **@options, class: class_names(BOX, @options[:class])
  end
end
