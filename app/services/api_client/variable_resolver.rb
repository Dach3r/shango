module ApiClient
  # Replaces `{{name}}` references with environment values (and a few dynamic `{{$...}}` helpers).
  # Unknown names stay untouched and are reported through `unresolved`.
  class VariableResolver
    PATTERN = /\{\{\s*([^{}\s]+)\s*\}\}/
    MAX_DEPTH = 5
    DYNAMIC = {
      "$timestamp" => -> { Time.current.to_i.to_s },
      "$isoTimestamp" => -> { Time.current.utc.iso8601 },
      "$guid" => -> { SecureRandom.uuid },
      "$randomInt" => -> { SecureRandom.random_number(1000).to_s }
    }.freeze

    attr_reader :unresolved

    # `extra` is an optional callable that gets the name when no variable or helper matches (e.g. response references).
    def initialize(values = {}, extra: nil)
      @values = values.transform_keys(&:to_s)
      @extra = extra
      @unresolved = Set.new
    end

    def resolve(text)
      return text unless text.is_a?(String) && text.include?("{{")

      result = text
      MAX_DEPTH.times do
        replaced = result.gsub(PATTERN) { |token| lookup(Regexp.last_match(1)) || token }
        break if replaced == result

        result = replaced
      end

      result.scan(PATTERN) { |(name)| @unresolved << name }
      result
    end

    def resolve_deep(object)
      case object
      when String then resolve(object)
      when Array then object.map { |item| resolve_deep(item) }
      when Hash then object.transform_values { |item| resolve_deep(item) }
      else object
      end
    end

    private

    def lookup(name)
      return @values[name] if @values.key?(name)

      DYNAMIC[name]&.call || @extra&.call(name)
    end
  end
end
