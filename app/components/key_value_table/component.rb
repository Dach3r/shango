class KeyValueTable::Component < ApplicationComponent
  VARIANTS = %i[pairs form_data variables].freeze

  # name: form scope for the rows (e.g. "api_request[headers]").
  # variants: :pairs (key/value/description), :form_data (adds text/file type), :variables (adds secret flag).
  def initialize(name:, rows:, variant: :pairs, key_placeholder: nil, value_placeholder: nil, add_label: nil, data: {}, files: true)
    @name = name
    @rows = rows.map { |row| row.respond_to?(:attributes) ? row.attributes : row.to_h }.map(&:stringify_keys)
    @variant = variant
    @rows = [{ "enabled" => true }] if pairs? && @rows.empty?
    @key_placeholder = key_placeholder || I18n.t("components.key_value_table.key")
    @value_placeholder = value_placeholder || I18n.t("components.key_value_table.value")
    @add_label = add_label || I18n.t("components.key_value_table.add")
    @data = data
    @files = files
  end

  private

  def pairs?
    @variant == :pairs
  end

  def form_data?
    @variant == :form_data
  end

  def wrapper_data
    { controller: "key-value-table", always_row: pairs? }.merge(@data)
  end

  def row_component(row, index)
    KeyValueTable::Row::Component.new(
      name: @name, row:, index:, variant: @variant, key_placeholder: @key_placeholder, value_placeholder: @value_placeholder, files: @files
    )
  end
end
