class Checkbox::Component < ApplicationComponent
  BOX = "peer size-5 cursor-pointer appearance-none rounded-md border border-line bg-field transition hover:border-accent/60 checked:border-solid checked:bg-solid focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-solid/30"
  LABEL = "flex cursor-pointer items-center gap-2.5 text-body"
  ICON = "pointer-events-none absolute inset-0 m-auto size-3.5 stroke-[3] text-on-solid opacity-0 transition peer-checked:opacity-100"

  # Pass `form:` + `attribute:` for model fields, or `name:` + `checked:` for plain params (submits "0" when unchecked).
  def initialize(label: nil, form: nil, attribute: nil, name: nil, checked: false, label_class: nil, **options)
    @label = label
    @form = form
    @attribute = attribute
    @name = name
    @checked = checked
    @label_class = label_class
    @options = options
  end

  private

  def label_classes
    class_names(LABEL, @label_class)
  end

  def icon_classes
    ICON
  end

  def field
    return @form.check_box(@attribute, **@options, class: class_names(BOX, @options[:class])) if @form

    safe_join [hidden_field_tag(@name, "0", id: nil), check_box_tag(@name, "1", @checked, id: nil, **@options, class: class_names(BOX, @options[:class]))]
  end
end
