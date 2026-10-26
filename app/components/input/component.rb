class Input::Component < ApplicationComponent
  LABEL = "mb-1.5 block text-sm font-medium text-muted"
  FIELD = "block w-full border border-line bg-field px-4 text-base text-ink transition placeholder:text-faint focus:border-solid focus:bg-field-focus focus:ring-1 focus:ring-solid focus:outline-none aria-invalid:border-danger aria-invalid:ring-1 aria-invalid:ring-danger aria-invalid:focus:border-danger"
  TEXT_FIELD = "min-h-28 py-3.5 leading-relaxed"
  ADORNMENT = "text-faint transition group-not-focus-within:group-has-[input:not(:placeholder-shown):not([aria-invalid=true])]:text-ink group-focus-within:text-solid group-has-[[aria-invalid=true]]:text-danger"
  TOGGLE = "#{ADORNMENT} hover:text-ink"
  ICON = ADORNMENT
  DEFAULT_ICONS = { email: "mail", password: "lock" }.freeze

  def initialize(form:, attribute:, label:, type: :text, icon: DEFAULT_ICONS[type], placeholder: nil, label_class: LABEL, **options)
    @form = form
    @attribute = attribute
    @label = label
    @type = type
    @icon = icon
    @placeholder = placeholder
    @label_class = label_class
    @options = options
  end

  private

  def text_area?
    @type == :text_area
  end

  def password?
    @type == :password
  end

  def label_classes
    @label_class
  end

  def icon_classes
    class_names("pointer-events-none absolute inset-y-0 left-4 flex items-center", ICON)
  end

  def toggle_classes
    class_names("absolute inset-y-0 right-4 flex items-center", TOGGLE)
  end

  def field
    html_options = @options.merge(
      placeholder: @placeholder,
      class: class_names(FIELD, (text_area? ? TEXT_FIELD : CONTROL_SIZE), @options[:class], "pl-11": @icon, "pr-12": password?)
    )
    html_options[:data] = (html_options[:data] || {}).merge(password_visibility_target: "input") if password?
    @form.public_send(text_area? ? "text_area" : "#{@type}_field", @attribute, **html_options)
  end
end
