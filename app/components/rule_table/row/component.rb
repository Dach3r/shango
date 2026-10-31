class RuleTable::Row::Component < ApplicationComponent
  include ControlsHelper

  def initialize(kind:, name:, row:, index:)
    @kind = kind
    @name = name
    @row = row
    @index = index
  end

  private

  attr_reader :row

  def assertion?
    @kind == :assertion
  end

  def field_name(field)
    "#{@name}[#{@index}][#{field}]"
  end

  def enabled?
    row.fetch("enabled", true) != false
  end

  def source
    row["source"].presence || (assertion? ? "status" : "json")
  end

  def sources
    assertion? ? ApiClient::Assertions::Catalog.sources : ApiClient::Assertions::Catalog::EXTRACTOR_SOURCES
  end

  def source_options
    sources.map { |name| [t("workbench.automation.sources.#{name}"), name] }
  end

  def operator_options
    ApiClient::Assertions::Catalog::OPERATORS.fetch(source).map { |name| [t("workbench.automation.operators.#{name}"), name] }
  end

  def operator
    row["operator"].presence || operator_options.first.last
  end

  def targeted?
    ApiClient::Assertions::Catalog.targeted?(source)
  end

  def expected?
    ApiClient::Assertions::Catalog.expects_value?(operator)
  end

  def target_placeholder
    t("workbench.automation.targets.#{source == "header" ? "header" : "json"}")
  end

  def secret?
    row["secret"] == true
  end

  def cell(extra = nil)
    field_classes("h-9 !py-0 text-xs #{extra}")
  end
end
