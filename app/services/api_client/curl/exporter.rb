module ApiClient
  module Curl
    # Renders a RequestBuilder::Built as a copy-pasteable curl command.
    class Exporter
      include Serviceable

      def initialize(built:)
        @built = built
      end

      private

      def perform
        parts = ["curl"]
        parts << "-X #{@built.http_method}" unless @built.http_method == "GET"
        parts << quote(@built.url)
        parts.concat(@built.headers.reject { |name, _| @built.defaults_added.include?(name) }.map { |name, value| "-H #{quote("#{name}: #{value}")}" })
        parts.concat(body_parts)
        parts << "-k" unless @built.verify_ssl
        parts << "-L" if @built.follow_redirects
        parts << "--max-time #{@built.timeout}"
        parts.join(" \\\n  ")
      end

      def body_parts
        body = @built.body
        if body.form
          body.form.map { |key, value| "-F #{quote("#{key}=#{value}")}" }
        elsif body.raw.present?
          ["--data-raw #{quote(body.raw)}"]
        elsif body.preview.present?
          ["--data-binary #{quote("@file")}"]
        else
          []
        end
      end

      def quote(text)
        "'#{text.to_s.gsub("'", "'\\\\''")}'"
      end
    end
  end
end
