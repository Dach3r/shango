# Editable rows of assertions or extractors (see ApiClient::Assertions). Like KeyValueTable it always keeps one blank row,
# which the model drops on save, so removing the last real row still posts something.
class RuleTable::Component < ApplicationComponent
  KINDS = %i[assertion extractor].freeze

  # name: form scope for the rows (e.g. "api_request[assertions]").
  def initialize(kind:, name:, rows:, add_label:)
    @kind = kind
    @name = name
    @rows = rows.presence || [{ "enabled" => true }]
    @add_label = add_label
  end

  private

  def wrapper_data
    { controller: "rule-table", rule_table_kind_value: @kind, rule_table_operators_value: operators.to_json, rule_table_labels_value: labels.to_json,
      rule_table_targeted_value: ApiClient::Assertions::Catalog::TARGETED.to_json, rule_table_expectless_value: ApiClient::Assertions::Catalog::EXPECTLESS.to_json }
  end

  def operators
    ApiClient::Assertions::Catalog::OPERATORS
  end

  def labels
    ApiClient::Assertions::Catalog::OPERATORS.values.flatten.uniq.index_with { |operator| I18n.t("workbench.automation.operators.#{operator}") }
  end

  def row_component(row, index)
    RuleTable::Row::Component.new(kind: @kind, name: @name, row:, index:)
  end
end
