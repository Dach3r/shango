module ApiClient
  module Exports
    # Turns assertion and extractor rows into a `pm` script, for formats that have no declarative equivalent (the Postman export).
    # A JSONPath is only translated when it is a plain property path (`$.a.b[0]`); the other rows are left as a comment saying so.
    class AssertionScript
      include Serviceable

      SIMPLE_PATH = /\A\$((\.[A-Za-z_]\w*)|(\[\d+\])|(\['[^'\\]*'\]))*\z/
      STATUS_CHECKS = { "equals" => "to.equal", "not_equals" => "to.not.equal", "lt" => "to.be.below", "gt" => "to.be.above" }.freeze
      NUMBER = /\A-?\d+(\.\d+)?\z/
      RANGE = /\A\s*(\d+)\s*-\s*(\d+)\s*\z/
      HEADER = "// Generated from the assertions and extractors of this Shango request."

      def initialize(assertions:, extractors:)
        @assertions = assertions.select { |row| row["enabled"] != false }
        @extractors = extractors.select { |row| row["enabled"] != false }
      end

      private

      def perform
        lines = @assertions.map { |row| assertion(row) } + @extractors.map { |row| extractor(row) }
        Result.success(lines.empty? ? "" : [HEADER, *lines].join("\n"))
      end

      def assertion(row)
        body = send(:"check_#{row["source"]}", row, row["expected"].to_s)
        return "// Not exported: #{Assertions::Describe.title(row.merge("kind" => "assertion")).gsub(/\s+/, " ")}" unless body

        "pm.test(#{Assertions::Describe.title(row.merge("kind" => "assertion")).to_json}, () => { #{body} });"
      end

      def check_status(row, expected)
        code = "pm.response.code"
        return "pm.expect(#{code}).to.be.within(#{Regexp.last_match(1)}, #{Regexp.last_match(2)});" if row["operator"] == "in_range" && expected =~ RANGE
        return unless expected.match?(NUMBER)

        check = STATUS_CHECKS[row["operator"]]
        check && "pm.expect(#{code}).#{check}(#{expected});"
      end

      def check_header(row, expected)
        value = "pm.response.headers.get(#{row["target"].to_json})"
        check = case row["operator"]
        when "exists" then "pm.expect(#{value}).to.exist;"
        when "not_exists" then "pm.expect(#{value}).to.not.exist;"
        when "equals" then "pm.expect(#{value}).to.equal(#{literal(expected)});"
        when "contains" then "pm.expect(String(#{value})).to.include(#{literal(expected)});"
        else "pm.expect(String(#{value})).to.match(new RegExp(#{literal(expected)}));"
        end
        check
      end

      def check_json(row, expected)
        access = access_path(row["target"])
        return unless access

        value = "pm.response.json()#{access}"
        text = "(typeof value === \"string\" ? value : JSON.stringify(value))"
        body = case row["operator"]
        when "exists" then "pm.expect(value).to.not.be.undefined;"
        when "not_exists" then "pm.expect(value).to.be.undefined;"
        when "equals" then "pm.expect(#{text}).to.equal(#{literal(expected)});"
        when "not_equals" then "pm.expect(#{text}).to.not.equal(#{literal(expected)});"
        when "contains" then "pm.expect(#{text}).to.include(#{literal(expected)});"
        when "matches" then "pm.expect(#{text}).to.match(new RegExp(#{literal(expected)}));"
        when "lt" then number(expected) && "pm.expect(Number(value)).to.be.below(#{expected});"
        when "gt" then number(expected) && "pm.expect(Number(value)).to.be.above(#{expected});"
        when "type" then "pm.expect(Array.isArray(value) ? \"array\" : value === null ? \"null\" : typeof value).to.equal(#{expected.to_json});"
        else number(expected) && "pm.expect(value).to.have.lengthOf(#{expected});"
        end
        body && "const value = #{value}; #{body}"
      end

      def check_body(row, expected)
        text = "pm.response.text()"
        case row["operator"]
        when "contains" then "pm.expect(#{text}).to.include(#{literal(expected)});"
        when "not_contains" then "pm.expect(#{text}).to.not.include(#{literal(expected)});"
        when "matches" then "pm.expect(#{text}).to.match(new RegExp(#{literal(expected)}));"
        else "pm.expect(#{text}).to.be.empty;"
        end
      end

      def check_time(_row, expected)
        number(expected) && "pm.expect(pm.response.responseTime).to.be.below(#{expected});"
      end

      def check_size(_row, expected)
        number(expected) && "pm.expect(pm.response.responseSize).to.be.below(#{expected});"
      end

      def extractor(row)
        name = row["variable"].to_json
        case row["source"]
        when "status" then "pm.environment.set(#{name}, pm.response.code);"
        when "body" then "pm.environment.set(#{name}, pm.response.text());"
        when "header" then store(name, "pm.response.headers.get(#{row["target"].to_json})")
        else (access = access_path(row["target"])) ? store(name, "pm.response.json()#{access}") : "// Not exported: extractor #{row["variable"]} reads #{row["target"]}"
        end
      end

      def store(name, expression)
        "try { const value = #{expression}; if (value !== undefined && value !== null) pm.environment.set(#{name}, typeof value === \"string\" ? value : JSON.stringify(value)); } catch (error) {}"
      end

      def access_path(path)
        path.to_s.delete_prefix("$") if path.to_s.match?(SIMPLE_PATH)
      end

      def number(text)
        text.match?(NUMBER)
      end

      # A value with `{{variables}}` is resolved by Postman when the script runs.
      def literal(text)
        text.include?("{{") ? "pm.variables.replaceIn(#{text.to_json})" : text.to_json
      end
    end
  end
end
