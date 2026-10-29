module Network
  module Lookups
    # Who is behind a domain or an IP address, from public registration data only: RDAP for a domain (registrar,
    # dates, status, nameservers, DNSSEC) and for an address (network, holder, abuse contact) plus its autonomous
    # system. The target is never contacted; only the registries and the fixed resolver are. A run has ten seconds in total.
    class Run
      include Serviceable

      TOTAL = 10

      def initialize(host:, environment: nil)
        @host = host
        @environment = environment
      end

      private

      def perform
        target = Target.call(raw: @host, environment: @environment)
        return target if target.failure?

        host = target.record
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + TOTAL
        ip = address(host)
        return Domain.call(host:, deadline:) unless ip
        return Result.failure(error: :private_address) if Network::SsrfPolicy.blocked?(ip.to_s)

        Address.call(ip:, host:, deadline:)
      end

      def address(host)
        IPAddr.new(host).native
      rescue IPAddr::Error
        nil
      end
    end
  end
end
