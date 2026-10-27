module Network
  module Dns
    # One line of the propagation table: what a nameserver answered (or why it did not).
    # `match` is :match, :mismatch or :no_answer when an expected value was given, else nil.
    class Row < Data.define(:name, :ip, :group, :status, :answers, :ttl, :ms, :match)
      ANSWERED = %i[ok cname].freeze

      def answered?
        ANSWERED.include?(status)
      end
    end
  end
end
