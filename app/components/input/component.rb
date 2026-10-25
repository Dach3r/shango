class Input::Component < ApplicationComponent
  LABEL_CLASSES = "mb-1.5 block text-sm font-medium text-neutral-700"
  INPUT_CLASSES = "block w-full rounded-xl border border-neutral-200 bg-neutral-50 px-4 py-3.5 text-neutral-900 placeholder:text-neutral-400 transition focus:border-brand-400 focus:bg-white focus:outline-none focus:ring-4 focus:ring-brand-500/25"

  def initialize(form:, attribute:, label:, type: :text, placeholder: nil, **options)
    @form = form
    @attribute = attribute
    @label = label
    @type = type
    @placeholder = placeholder
    @options = options
  end

  private

  def password?
    @type == :password
  end

  def field
    html_options = @options.merge(
      placeholder: @placeholder,
      class: class_names(INPUT_CLASSES, @options[:class], "pr-12": password?)
    )
    html_options[:data] = (html_options[:data] || {}).merge(password_visibility_target: "input") if password?
    @form.public_send("#{@type}_field", @attribute, **html_options)
  end
end
