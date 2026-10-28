module ApiClient
  module Exports
    # Turns "requests written so far" into a 0-90 percentage and reports it only when it changes; the remaining
    # steps (serializing, storing) are reported by Export.
    class Progress
      BUILD_SHARE = 90

      def initialize(total:, &report)
        @total = total
        @report = report
        @done = 0
        @percent = nil
      end

      def advance(count)
        @done += count
        update(@total.zero? ? BUILD_SHARE : [@done * BUILD_SHARE / @total, BUILD_SHARE].min)
      end

      def update(percent)
        return if percent == @percent

        @percent = percent
        @report&.call(percent)
      end
    end
  end
end
