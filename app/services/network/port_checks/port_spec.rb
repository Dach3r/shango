module Network
  module PortChecks
    # Parses what the user typed into a sorted list of unique ports: numbers, ranges (`8000-8010`) and the
    # `common` preset, separated by commas or spaces. Fails when a token is invalid or there are too many ports.
    class PortSpec
      include Serviceable

      MAX_PORTS = 100
      VALID = (1..65_535)
      COMMON = [21, 22, 25, 53, 80, 110, 143, 443, 465, 587, 993, 995, 3000, 3306, 5432, 6379, 8080, 8443, 27_017].freeze

      def initialize(raw:)
        @raw = raw.to_s
      end

      private

      def perform
        tokens = @raw.downcase.split(/[\s,]+/).compact_blank
        return Result.failure(error: :blank_ports) if tokens.empty?

        ports = []
        tokens.each do |token|
          expanded = expand(token)
          return Result.failure(error: :invalid_ports, token: token.truncate(20)) unless expanded

          ports = (ports + expanded).uniq
          return too_many if ports.size > MAX_PORTS
        end

        Result.success(ports.sort)
      end

      def too_many
        Result.failure(error: :too_many_ports, max: MAX_PORTS)
      end

      # The ports a token stands for, or nil when it is not valid.
      def expand(token)
        return COMMON if token == "common"

        first, last = token.match(/\A(\d+)(?:-(\d+))?\z/)&.captures&.map { |number| number&.to_i }
        return unless first && VALID.cover?(first)
        return [first] unless last
        return unless VALID.cover?(last) && last >= first

        (first..last).to_a
      end
    end
  end
end
