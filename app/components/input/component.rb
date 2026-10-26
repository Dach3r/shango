class Input::Component < ApplicationComponent
  LABEL = "mb-1.5 block text-sm font-medium text-body"
  FIELD = "block w-full rounded-xl border border-line bg-field #{CONTROL_SIZE} px-4 text-base text-ink transition placeholder:text-muted/60 focus:border-solid focus:bg-field-focus focus:ring-4 focus:ring-solid/45 focus:outline-none aria-invalid:border-danger aria-invalid:ring-4 aria-invalid:ring-danger/25 aria-invalid:focus:border-danger"
  TOGGLE = "text-muted hover:text-ink"
  ICON = "text-muted"
  DEFAULT_ICONS = {email: "mail", password: "lock"}.freeze

  def initialize(form:, attribute:, label:, type: :text, icon: DEFAULT_ICONS[type], placeholder: nil, **options)
    @form = form
    @attribute = attribute
    @label = label
    @type = type
    @icon = icon
    @placeholder = placeholder
    @options = options
  end

  private

  def password?
    @type == :password
  end

  def label_classes
    LABEL
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
      class: class_names(FIELD, @options[:class], "pl-11": @icon, "pr-12": password?)
    )
    html_options[:data] = (html_options[:data] || {}).merge(password_visibility_target: "input") if password?
    @form.public_send("#{@type}_field", @attribute, **html_options)
  end
end
