module ApiClient
  module Imports
    # Rewrites foreign `{{ ... }}` references to Shango's syntax; unsupported dynamic helpers are reported once.
    module VariableConverter
      PATTERN = /\{\{\s*([^{}]+?)\s*\}\}/
      ALIASES = { "$randomUUID" => "$guid", "$randomInt" => "$randomInt", "$timestamp" => "$timestamp", "$isoTimestamp" => "$isoTimestamp", "$guid" => "$guid" }.freeze

      module_function

      def call(text, warnings = [])
        return text unless text.is_a?(String) && text.include?("{{")

        text.gsub(PATTERN) do
          name = Regexp.last_match(1)
          next "{{#{name.delete_prefix("_.").strip}}}" if name.start_with?("_.")
          next "{{#{ALIASES[name]}}}" if ALIASES.key?(name)

          if name.start_with?("$")
            warn_once(warnings, name)
            next Regexp.last_match(0)
          end

          "{{#{name}}}"
        end
      end

      def request(attributes, warnings)
        attributes.merge(
          url: call(attributes[:url], warnings), body: call(attributes[:body], warnings),
          graphql_variables: call(attributes[:graphql_variables], warnings),
          headers: rows(attributes[:headers], warnings), query_params: rows(attributes[:query_params], warnings),
          body_form: rows(attributes[:body_form], warnings),
          auth_config: attributes[:auth_config].transform_values { |value| call(value, warnings) }
        )
      end

      def rows(rows, warnings)
        rows.map { |row| row.merge("key" => call(row["key"], warnings), "value" => call(row["value"], warnings)) }
      end

      def warn_once(warnings, name)
        message = I18n.t("workbench.imports.warnings.variable_unsupported", name:)
        warnings << message unless warnings.include?(message)
      end
    end
  end
end
