module Network
  module Dns
    # One question to one nameserver. Always returns an Answer: failures are statuses, not exceptions, because a
    # resolver that times out is a normal row of the propagation table.
    #
    # Statuses: ok, cname (only an alias came back), nodata, nxdomain, servfail, refused, timeout, error.
    class Query
      include Serviceable

      Answer = Data.define(:status, :answers, :ttl, :ms)

      TYPES = {
        "A" => Resolv::DNS::Resource::IN::A, "AAAA" => Resolv::DNS::Resource::IN::AAAA,
        "CNAME" => Resolv::DNS::Resource::IN::CNAME, "MX" => Resolv::DNS::Resource::IN::MX,
        "TXT" => Resolv::DNS::Resource::IN::TXT, "NS" => Resolv::DNS::Resource::IN::NS,
        "SOA" => Resolv::DNS::Resource::IN::SOA, "CAA" => Resolv::DNS::Resource::IN::CAA,
        "PTR" => Resolv::DNS::Resource::IN::PTR
      }.freeze
      DEFAULT_TIMEOUT = 3
      RCODES = {
        Resolv::DNS::RCode::NXDomain => :nxdomain, Resolv::DNS::RCode::ServFail => :servfail,
        Resolv::DNS::RCode::Refused => :refused
      }.freeze

      def initialize(ip:, name:, type:, timeout: DEFAULT_TIMEOUT, port: Transport::PORT)
        @ip = ip
        @name = name
        @type = TYPES.fetch(type)
        @timeout = timeout
        @port = port
        @id = SecureRandom.random_number(0x10000)
      end

      private

      def perform
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        status, records = interpret(exchange)
        answers = records.map { |_ttl, data| stringify(data) }
        Answer.new(status:, answers:, ttl: records.map(&:first).min, ms: elapsed(started))
      rescue Transport::TimedOut
        failed(:timeout, started)
      rescue Transport::Failed, Resolv::DNS::DecodeError
        failed(:error, started)
      end

      def failed(status, started)
        Answer.new(status:, answers: [], ttl: nil, ms: elapsed(started))
      end

      def elapsed(started)
        ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      end

      def exchange
        payload = question.encode
        reply = decode(Transport.udp(ip: @ip, payload:, timeout: @timeout, port: @port))
        return reply unless reply.tc == 1

        decode(Transport.tcp(ip: @ip, payload:, timeout: @timeout, port: @port))
      end

      def question
        Resolv::DNS::Message.new(@id).tap do |message|
          message.rd = 1
          message.add_question(@name, @type)
        end
      end

      def decode(bytes)
        message = Resolv::DNS::Message.decode(bytes)
        raise Transport::Failed, "mismatched reply" unless message.id == @id

        message
      end

      # [status, [[ttl, data], ...]] for the records that answer the question.
      def interpret(reply)
        status = RCODES.fetch(reply.rcode) { reply.rcode.zero? ? :ok : :error }
        return [status, []] unless status == :ok

        answers = reply.answer.map { |_name, ttl, data| [ttl, data] }
        matching = answers.select { |_ttl, data| data.is_a?(@type) }
        return [:ok, matching] if matching.any?

        aliases = answers.select { |_ttl, data| data.is_a?(Resolv::DNS::Resource::IN::CNAME) }
        aliases.any? ? [:cname, aliases] : [:nodata, []]
      end

      def stringify(data)
        case data
        when Resolv::DNS::Resource::IN::A, Resolv::DNS::Resource::IN::AAAA then data.address.to_s
        when Resolv::DNS::Resource::IN::CNAME, Resolv::DNS::Resource::IN::NS, Resolv::DNS::Resource::IN::PTR then data.name.to_s
        when Resolv::DNS::Resource::IN::MX then "#{data.preference} #{data.exchange.to_s.presence || "."}"
        when Resolv::DNS::Resource::IN::TXT then data.strings.join
        when Resolv::DNS::Resource::IN::SOA then [data.mname, data.rname, data.serial, data.refresh, data.retry, data.expire, data.minimum].join(" ")
        else "#{data.flags} #{data.tag} #{data.value}"
        end
      end
    end
  end
end
