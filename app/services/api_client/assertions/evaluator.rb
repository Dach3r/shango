module ApiClient
  module Assertions
    # Checks a response against the enabled assertion rows (see Catalog) and returns one outcome hash per row:
    # `{ "kind", "status" (passed|failed), "source", "target", "operator", "expected", "actual", "error" }`.
    # `expected` keeps the row as typed (variables unresolved) and `actual` goes through the masker, so an outcome is safe to store.
    class Evaluator
      include Serviceable

      Response = Struct.new(:status, :headers, :body, :duration_ms, :size_bytes, keyword_init: true)
      Failure = Class.new(StandardError) do
        def key
          message
        end
      end

      INVALID = Object.new.freeze
      MAX_ACTUAL = 200
      REGEXP_TIMEOUT = 0.5
      RANGE = /\A\s*(\d+)\s*-\s*(\d+)\s*\z/

      def initialize(rows:, response:, resolver: nil, masker: nil)
        @rows = rows
        @response = response
        @resolver = resolver
        @masker = masker
      end

      private

      def perform
        @rows.select { |row| row["enabled"] != false }.map { |row| evaluate(row) }
      end

      def evaluate(row)
        source = row["source"]
        operator = row["operator"]
        return outcome(row, "failed", error: "unsupported") unless Catalog.valid_assertion?(source, operator)

        expected = resolve(row["expected"])
        passed, actual = send(:"check_#{source}", row["target"].to_s, operator, expected)
        outcome(row, passed ? "passed" : "failed", actual:)
      rescue Failure => error
        outcome(row, "failed", error: error.key)
      end

      def check_status(_target, operator, expected)
        actual = @response.status.to_i
        passed = case operator
        when "equals" then actual == number(expected)
        when "not_equals" then actual != number(expected)
        when "lt" then actual < number(expected)
        when "gt" then actual > number(expected)
        else in_range?(actual, expected)
        end
        [passed, actual]
      end

      def check_header(target, operator, expected)
        value = header(target)
        passed = case operator
        when "exists" then !value.nil?
        when "not_exists" then value.nil?
        when "equals" then value == expected
        when "contains" then !value.nil? && value.include?(expected)
        else !value.nil? && matches?(value, expected)
        end
        [passed, value]
      end

      def check_json(target, operator, expected)
        found = json_matches(target)
        return [operator == "exists" ? !found.empty? : found.empty?, nil] if %w[exists not_exists].include?(operator)
        raise Failure, "not_found" if found.empty?

        value = found.size == 1 ? found.first : found
        [json_check(operator, value, expected), text(value)]
      end

      def json_check(operator, value, expected)
        case operator
        when "equals" then text(value) == expected
        when "not_equals" then text(value) != expected
        when "contains" then json_contains?(value, expected)
        when "matches" then matches?(text(value), expected)
        when "lt" then numeric(value) < number(expected)
        when "gt" then numeric(value) > number(expected)
        when "type" then type_of(value) == expected
        else length_of(value) == number(expected)
        end
      end

      def check_body(_target, operator, expected)
        body = body_text
        passed = case operator
        when "contains" then body.include?(expected)
        when "not_contains" then !body.include?(expected)
        when "matches" then matches?(body, expected)
        else body.empty?
        end
        [passed, nil]
      end

      def check_time(_target, _operator, expected)
        [@response.duration_ms.to_i < number(expected), @response.duration_ms]
      end

      def check_size(_target, _operator, expected)
        [@response.size_bytes.to_i < number(expected), @response.size_bytes]
      end

      def header(name)
        pair = @response.headers.to_a.find { |key, _| key.to_s.casecmp?(name) }
        pair&.last&.to_s
      end

      def body_text
        @body_text ||= begin
          text = @response.body.to_s.dup.force_encoding(Encoding::UTF_8)
          text.valid_encoding? ? text : text.scrub("")
        end
      end

      def json_matches(path)
        document = parsed_json
        raise Failure, "invalid_json" if document.equal?(INVALID)

        JsonPath.new(path).on(document)
      rescue ArgumentError
        raise Failure, "invalid_path"
      end

      def parsed_json
        return @json if defined?(@json)

        @json = JSON.parse(body_text)
      rescue JSON::ParserError
        @json = INVALID
      end

      def json_contains?(value, expected)
        case value
        when Array then value.any? { |item| text(item) == expected }
        when Hash then value.key?(expected)
        else text(value).include?(expected)
        end
      end

      def in_range?(actual, expected)
        match = RANGE.match(expected) or raise Failure, "invalid_expected"
        actual.between?(match[1].to_i, match[2].to_i)
      end

      def matches?(value, pattern)
        Regexp.new(pattern, timeout: REGEXP_TIMEOUT).match?(value.to_s)
      rescue Regexp::TimeoutError
        raise Failure, "pattern_timeout"
      rescue RegexpError
        raise Failure, "invalid_pattern"
      end

      def number(value)
        Float(value.to_s.strip)
      rescue ArgumentError
        raise Failure, "invalid_expected"
      end

      def numeric(value)
        Float(value)
      rescue ArgumentError, TypeError
        raise Failure, "not_a_number"
      end

      def length_of(value)
        return value.size if value.is_a?(String) || value.is_a?(Array) || value.is_a?(Hash)

        raise Failure, "no_length"
      end

      def type_of(value)
        case value
        when String then "string"
        when Numeric then "number"
        when true, false then "boolean"
        when Array then "array"
        when Hash then "object"
        else "null"
        end
      end

      def text(value)
        value.is_a?(String) ? value : value.to_json
      end

      def resolve(value)
        @resolver ? @resolver.resolve(value.to_s) : value.to_s
      end

      def outcome(row, status, actual: nil, error: nil)
        shown = actual.nil? ? nil : mask(actual.to_s).truncate(MAX_ACTUAL)
        { "kind" => "assertion", "status" => status, "source" => row["source"], "target" => row["target"].to_s, "operator" => row["operator"],
          "expected" => row["expected"].to_s, "actual" => shown, "error" => error }
      end

      def mask(text)
        @masker ? @masker.string(text) : text
      end
    end
  end
end
