module ApiClient
  module Assertions
    # Reads values out of a response for the enabled extractor rows (`{ "source", "target", "variable", "secret" }`).
    # Result#record is `{ variable => value }` for what was found; Result#data[:secrets] lists the variables the rows mark as
    # secret and Result#data[:outcomes] has one outcome per row (`passed`, or `warning` when the value is not in the response).
    class Extractor
      include Serviceable

      MAX_VALUE = 64.kilobytes

      def initialize(rows:, response:)
        @rows = rows
        @response = response
      end

      private

      def perform
        values = {}
        secrets = []
        outcomes = @rows.select { |row| row["enabled"] != false }.map do |row|
          value = read(row)
          if value.nil?
            outcome(row, "warning", "not_found")
          else
            values[row["variable"]] = value.to_s.byteslice(0, MAX_VALUE).scrub("")
            secrets << row["variable"] if row["secret"]
            outcome(row, "passed")
          end
        end
        Result.success(values, secrets:, outcomes:)
      end

      def read(row)
        return unless Catalog::EXTRACTOR_SOURCES.include?(row["source"]) && row["variable"].to_s.match?(Variable::KEY_FORMAT)

        case row["source"]
        when "status" then @response.status
        when "header" then header(row["target"].to_s)
        when "body" then @response.body.presence&.to_s
        else json(row["target"].to_s)
        end
      end

      def header(name)
        @response.headers.to_a.find { |key, _| key.to_s.casecmp?(name) }&.last&.to_s
      end

      def json(path)
        found = JsonPath.new(path).on(JSON.parse(@response.body.to_s))
        value = found.size == 1 ? found.first : found.presence
        value.is_a?(String) || value.nil? ? value : value.to_json
      rescue JSON::ParserError, ArgumentError
        nil
      end

      def outcome(row, status, error = nil)
        { "kind" => "extractor", "status" => status, "source" => row["source"], "target" => row["target"].to_s, "variable" => row["variable"].to_s, "error" => error }
      end
    end
  end
end
