class KeyValueTable::Component < ApplicationComponent
  VARIANTS = %i[pairs form_data variables].freeze

  # name: form scope for the rows (e.g. "api_request[headers]").
  # variants: :pairs (key/value/description), :form_data (adds text/file type), :variables (adds secret flag).
  def initialize(name:, rows:, variant: :pairs, key_placeholder: nil, value_placeholder: nil, data: {})
    @name = name
    @rows = rows.map { |row| row.respond_to?(:attributes) ? row.attributes : row.to_h }.map(&:stringify_keys)
    @variant = variant
    @key_placeholder = key_placeholder || I18n.t("components.key_value_table.key")
    @value_placeholder = value_placeholder || I18n.t("components.key_value_table.value")
    @data = data
  end

  private

  def wrapper_data
    { controller: "key-value-table" }.merge(@data)
  end

  def row_component(row, index)
    KeyValueTable::Row::Component.new(
      name: @name, row:, index:, variant: @variant, key_placeholder: @key_placeholder, value_placeholder: @value_placeholder
    )
  end
end
