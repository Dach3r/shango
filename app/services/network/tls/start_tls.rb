module Network
  module Tls
    # The plain-text dialog that upgrades a mail connection to TLS (SMTP, IMAP or POP3), up to the server's go-ahead.
    # Reply lines are read up to MAX_LINE bytes; anything unexpected raises Refused.
    class StartTls
      class Refused < StandardError; end

      PROTOCOLS = %w[smtp imap pop3].freeze
      MAX_LINE = 4096
      HELO_NAME = "shango.invalid".freeze

      def self.call(socket:, protocol:, deadline:)
        new(socket, deadline).public_send(protocol)
      end

      def initialize(socket, deadline)
        @socket = socket
        @deadline = deadline
        @buffer = +""
      end

      def smtp
        expect(smtp_reply, "220")
        send_line("EHLO #{HELO_NAME}")
        features = smtp_reply
        expect(features, "250")
        raise Refused unless features.any? { |line| line[4..].to_s.strip.casecmp?("STARTTLS") }

        send_line("STARTTLS")
        expect(smtp_reply, "220")
      end

      def imap
        greeting = read_line
        raise Refused unless greeting.start_with?("* OK", "* PREAUTH")

        send_line("a1 STARTTLS")
        line = read_line
        line = read_line while line.start_with?("* ")
        raise Refused unless line.start_with?("a1 OK")
      end

      def pop3
        raise Refused unless read_line.start_with?("+OK")

        send_line("STLS")
        raise Refused unless read_line.start_with?("+OK")
      end

      private

      # Lines of one SMTP reply: `250-...` continues it, `250 ...` ends it.
      def smtp_reply
        lines = [read_line]
        lines << read_line while lines.last[3] == "-"
        lines
      end

      def expect(lines, code)
        raise Refused unless lines.all? { |line| line.start_with?(code) }
      end

      def send_line(text)
        @socket.write("#{text}\r\n")
      end

      def read_line
        until (index = @buffer.index("\n"))
          raise Refused if @buffer.bytesize >= MAX_LINE

          Handshake.wait(@socket, :wait_readable, @deadline)
          @buffer << @socket.readpartial(MAX_LINE - @buffer.bytesize)
        end
        @buffer.slice!(0..index).chomp
      end
    end
  end
end
