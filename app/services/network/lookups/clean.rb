module Network
  module Lookups
    # Text read from a registry or a DNS answer is not under our control: only strings are kept, trimmed and cut.
    module Clean
      LIMIT = 255

      module_function

      def text(value, limit: LIMIT)
        value.strip.first(limit).presence if value.is_a?(String)
      end

      # A date as UTC ISO 8601, or nil when it cannot be read.
      def time(value)
        Time.zone.parse(value).utc.iso8601 if value.is_a?(String)
      rescue ArgumentError
        nil
      end
    end
  end
end
