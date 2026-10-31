# Assertion and extractor rows (see ApiClient::Assertions) of a request, folder or collection. Setters clean what the form
# posts: rows with an unknown source or operator or without what they need are dropped, so only rows the evaluator
# understands are stored. A variable name that is not valid is an error, not a silent drop.
module TestAutomation
  extend ActiveSupport::Concern

  MAX_TARGET = 500
  MAX_EXPECTED = 1_000

  MAX_SCRIPT = 64.kilobytes

  included do
    before_validation :normalize_automation
    validate :extractor_variables_are_valid
    validates :pre_request_script, :post_response_script, length: { maximum: MAX_SCRIPT, tokenizer: ->(script) { script.to_s.bytes } }, allow_nil: true
  end

  def assertions=(rows)
    super(TestAutomation.clean_assertions(rows))
  end

  def extractors=(rows)
    super(TestAutomation.clean_extractors(rows))
  end

  # A script that is only blank space is no script.
  def pre_request_script=(source)
    super(source.presence&.to_s&.rstrip)
  end

  def post_response_script=(source)
    super(source.presence&.to_s&.rstrip)
  end

  private

  def normalize_automation
    self.assertions = assertions
    self.extractors = extractors
  end

  def extractor_variables_are_valid
    errors.add(:base, :invalid_extractor_variable) if extractors.any? { |row| row["variable"].to_s !~ Variable::KEY_FORMAT }
  end

  class << self
    def clean_assertions(rows)
      each_row(rows).filter_map do |row|
        source = row["source"].to_s
        operator = row["operator"].to_s
        next unless ApiClient::Assertions::Catalog.valid_assertion?(source, operator)

        target = ApiClient::Assertions::Catalog.targeted?(source) ? row["target"].to_s.strip.first(MAX_TARGET) : ""
        expected = ApiClient::Assertions::Catalog.expects_value?(operator) ? row["expected"].to_s.first(MAX_EXPECTED) : ""
        next if (ApiClient::Assertions::Catalog.targeted?(source) && target.empty?) || (ApiClient::Assertions::Catalog.expects_value?(operator) && expected.empty?)

        { "id" => identifier(row), "enabled" => enabled?(row), "source" => source, "target" => target, "operator" => operator, "expected" => expected }
      end.first(ApiClient::Assertions::Catalog::MAX_ROWS)
    end

    def clean_extractors(rows)
      each_row(rows).filter_map do |row|
        source = row["source"].to_s
        variable = row["variable"].to_s.strip
        next unless ApiClient::Assertions::Catalog::EXTRACTOR_SOURCES.include?(source) && variable.present?

        target = ApiClient::Assertions::Catalog.targeted?(source) ? row["target"].to_s.strip.first(MAX_TARGET) : ""
        next if ApiClient::Assertions::Catalog.targeted?(source) && target.empty?

        { "id" => identifier(row), "enabled" => enabled?(row), "source" => source, "target" => target, "variable" => variable.first(100),
          "secret" => ActiveModel::Type::Boolean.new.cast(row["secret"]) == true }
      end.first(ApiClient::Assertions::Catalog::MAX_ROWS)
    end

    private

    def each_row(rows)
      list = rows.respond_to?(:values) && !rows.is_a?(Array) ? rows.values : Array(rows)
      list.filter_map { |row| row.to_h.stringify_keys if row.respond_to?(:to_h) }
    end

    def identifier(row)
      row["id"].to_s.match?(/\A\h{8}\z/) ? row["id"].to_s : SecureRandom.hex(4)
    end

    def enabled?(row)
      ActiveModel::Type::Boolean.new.cast(row.fetch("enabled", true)) != false
    end
  end
end
