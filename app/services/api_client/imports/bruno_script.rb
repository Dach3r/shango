module ApiClient
  module Imports
    # Rewrites the Bruno script calls that have a Postman (and so a Shango) twin; everything else stays as written for the
    # importer to report (see Support.unsupported_apis).
    module BrunoScript
      REPLACEMENTS = [
        [/\bbru\.setEnvVar\(/, "pm.environment.set("], [/\bbru\.getEnvVar\(/, "pm.environment.get("],
        [/\bbru\.setVar\(/, "pm.variables.set("], [/\bbru\.getVar\(/, "pm.variables.get("],
        [/(?<![\w.])res\.getStatus\(\)/, "pm.response.code"], [/(?<![\w.])res\.status\b(?!Text)/, "pm.response.code"],
        [/(?<![\w.])res\.getBody\(\)/, "pm.response.json()"], [/(?<![\w.])res\.body\b/, "pm.response.json()"],
        [/(?<![\w.])res\.getHeader\(/, "pm.response.headers.get("], [/(?<![\w.])res\.getResponseTime\(\)/, "pm.response.responseTime"],
        [/(?<![\w.])res\.responseTime\b/, "pm.response.responseTime"], [/(?<![\w.])req\.getUrl\(\)/, "pm.request.url"],
        [/(?<![\w.])test\(/, "pm.test("], [/(?<![\w.])expect\(/, "pm.expect("]
      ].freeze

      module_function

      def call(source:)
        REPLACEMENTS.reduce(source.to_s) { |script, (pattern, replacement)| script.gsub(pattern, replacement) }.strip
      end
    end
  end
end
