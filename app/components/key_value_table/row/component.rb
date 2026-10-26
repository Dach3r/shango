class KeyValueTable::Row::Component < ApplicationComponent
  include ControlsHelper

  def initialize(name:, row:, index:, variant:, key_placeholder:, value_placeholder:)
    @name = name
    @row = row
    @index = index
    @variant = variant
    @key_placeholder = key_placeholder
    @value_placeholder = value_placeholder
  end

  private

  attr_reader :row, :variant

  def cell_classes(extra)
    field_classes("!border-transparent !bg-transparent hover:!bg-field focus:!bg-field-focus h-9 !py-0 #{extra}")
  end

  def field_name(field)
    "#{@name}[#{@index}][#{field}]"
  end

  def enabled?
    row.fetch("enabled", true) != false
  end

  def secret?
    row["secret"] == true
  end

  def file?
    row["type"] == "file"
  end

  def persisted?
    row["id"].present?
  end

  # Files are posted under body_uploads[<token>], tied to their row by this token.
  def upload_token
    row["upload_token"].presence || (@index == "NEW_INDEX" ? "NEW_INDEX" : SecureRandom.hex(6))
  end

  def upload_name
    @name.sub(/\[body_form\]\z/, "[body_uploads]") + "[#{upload_token}]"
  end

  def value_type
    secret? ? "password" : "text"
  end

  def value_text
    secret? ? "" : row["value"]
  end

  def value_hint
    secret? && persisted? ? t("components.key_value_table.secret_saved") : @value_placeholder
  end
end
