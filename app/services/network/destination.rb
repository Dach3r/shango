module Network
  # Resolves a host to the address a probe connects to, after the outbound guard (`SsrfPolicy`) approved it.
  # Probes connect to this address, never to the name, so the answer cannot change between check and connect.
  class Destination
    include Serviceable

    def initialize(host:)
      @host = host
    end

    private

    def perform
      address = Network::SsrfPolicy.check!(@host) || Addrinfo.getaddrinfo(@host, nil, nil, :STREAM).first.ip_address
      Result.success(address)
    rescue Network::SsrfPolicy::Blocked => error
      Result.failure(error: :blocked, detail: error.message)
    rescue SocketError
      Result.failure(error: :unresolved)
    end
  end
end
