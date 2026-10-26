class CodeEditor::Component < ApplicationComponent
  FALLBACK = "block w-full rounded-lg border border-line bg-field px-3 py-2 font-mono text-xs text-ink"

  def initialize(value: "", name: nil, id: nil, language: "text", readonly: false, single_line: false, placeholder: nil, variables: [], form: nil, data: {}, input_data: {}, **options)
    @value = value.to_s
    @name = name
    @id = id
    @language = language
    @readonly = readonly
    @single_line = single_line
    @placeholder = placeholder
    @variables = variables
    @form = form
    @data = data
    @input_data = input_data
    @options = options
  end

  private

  def wrapper_data
    {
      controller: "code-editor", code_editor_language_value: @language, code_editor_readonly_value: @readonly,
      code_editor_single_line_value: @single_line, code_editor_placeholder_value: @placeholder, code_editor_variables_value: @variables.to_json
    }.merge(@data)
  end

  def wrapper_classes
    class_names("code-editor min-h-0", "overflow-hidden", @options[:class])
  end

  def field_options
    { id: @id, form: @form, readonly: @readonly, placeholder: @placeholder, class: FALLBACK, rows: (@single_line ? 1 : 8), data: { code_editor_target: "input" }.merge(@input_data) }.compact
  end
end
