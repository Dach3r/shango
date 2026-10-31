module ApiClient
  module Imports
    # Helpers shared by the format importers: they all build the same request hash `Curl::Parser` produces.
    module Support
      MAX_NODES = 250_000
      AUTOMATION_KEYS = %i[pre_request_script post_response_script assertions extractors].freeze
      # What imported scripts may call that Shango's `pm` does not have, so the importer can tell the user what will fail.
      UNSUPPORTED_APIS = {
        "pm.sendRequest" => /\bpm\.sendRequest\b/, "pm.cookies" => /\bpm\.cookies\b/, "pm.globals" => /\bpm\.globals\b/, "pm.iterationData" => /\bpm\.iterationData\b/,
        "pm.execution" => /\bpm\.execution\b/, "pm.visualizer" => /\bpm\.visualizer\b/, "postman.*" => /\bpostman\.[a-zA-Z]/, "CryptoJS" => /\bCryptoJS\b/,
        "require()" => /\brequire\s*\(/, "lodash" => /(?<![\w.])_\.[a-zA-Z]/, "moment" => /\bmoment\s*\(/, "xml2Json" => /\bxml2Json\b/, "tv4" => /\btv4\b/,
        "atob/btoa" => /\b(atob|btoa)\s*\(/, "bru.*" => /\bbru\.[a-zA-Z]/, "req.*" => /(?<![\w.])req\.[a-zA-Z]/, "res.*" => /(?<![\w.])res\.[a-zA-Z]/
      }.freeze

      module_function

      def row(key, value, enabled: true, description: nil)
        { "key" => key.to_s, "value" => value.to_s, "enabled" => enabled != false, "description" => description.to_s }
      end

      def request(name:, http_method: "GET", url: "", query_params: [], **attributes)
        method = http_method.to_s.upcase
        base = url.to_s.split("?", 2).first.to_s
        enabled = query_params.select { |param| param["enabled"] && param["key"].present? }
        full_url = enabled.any? ? "#{base}?#{enabled.map { |param| [param["key"], param["value"].presence].compact.join("=") }.join("&")}" : url.to_s
        {
          name: name.to_s.strip.presence || "Untitled request", http_method: ApiRequest::METHODS.include?(method) ? method : "GET",
          url: full_url, query_params:, headers: [], body_type: "none", body: nil, body_form: [], graphql_variables: nil,
          auth_type: AuthConfigurable::INHERIT, auth_config: {}, settings: {}, description: nil
        }.merge(attributes)
      end

      def folder(name:, folders: [], requests: [], auth_type: AuthConfigurable::INHERIT, auth_config: {})
        { name: name.to_s.strip.presence || "Untitled folder", folders:, requests:, auth_type:, auth_config: }
      end

      # The names of the APIs a script uses that Shango's `pm` does not offer.
      def unsupported_apis(source)
        UNSUPPORTED_APIS.select { |_name, pattern| source.to_s.match?(pattern) }.keys
      end

      def environment(name:, variables: [])
        { name: name.to_s.strip.presence || "Imported environment", variables: }
      end

      def variable(key, value, secret: false, enabled: true)
        { key: key.to_s, value: value.to_s, secret: secret == true, enabled: enabled != false }
      end

      def body_type_for(mime)
        type = mime.to_s.downcase
        if type.include?("json") then "json"
        elsif type.include?("xml") then "xml"
        elsif type.include?("x-www-form-urlencoded") then "form_urlencoded"
        elsif type.include?("multipart") then "multipart"
        else "text"
        end
      end

      def count_nodes(value)
        case value
        when Hash then 1 + value.values.sum { |child| count_nodes(child) }
        when Array then 1 + value.sum { |child| count_nodes(child) }
        else 1
        end
      end
    end
  end
end
