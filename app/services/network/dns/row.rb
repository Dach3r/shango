module Network
  module Dns
    class Row < Data.define(:name, :ip, :group, :status, :answers, :ttl, :ms, :match)
      ANSWERED = %i[ok cname].freeze

      def answered?
        ANSWERED.include?(status)
      end
    end
  end
end
