module ApiClient
  module Assertions
    # What an assertion or an extractor row may say. The editor builds its selects from here and `TestAutomation`
    # drops anything else, so a forged form cannot store an operator the evaluator does not know.
    module Catalog
      OPERATORS = {
        "status" => %w[equals not_equals lt gt in_range],
        "header" => %w[exists not_exists equals contains matches],
        "json" => %w[exists not_exists equals not_equals contains matches lt gt type length],
        "body" => %w[contains not_contains matches is_empty],
        "time" => %w[lt],
        "size" => %w[lt]
      }.freeze
      EXTRACTOR_SOURCES = %w[json header status body].freeze
      TARGETED = %w[header json].freeze
      EXPECTLESS = %w[exists not_exists is_empty].freeze
      TYPES = %w[string number boolean array object null].freeze
      MAX_ROWS = 50

      module_function

      def sources
        OPERATORS.keys
      end

      def valid_assertion?(source, operator)
        OPERATORS.fetch(source, []).include?(operator)
      end

      def targeted?(source)
        TARGETED.include?(source)
      end

      def expects_value?(operator)
        EXPECTLESS.exclude?(operator)
      end
    end
  end
end
