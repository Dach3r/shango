module Monitoring
  # Monitors run unattended, so on top of the outbound guard (`Network::SsrfPolicy`, which an operator may switch off to
  # monitor internal services) cloud metadata addresses are always refused.
  module Guard
    METADATA = %w[169.254.0.0/16 fd00:ec2::254/128].map { |range| IPAddr.new(range) }.freeze

    module_function

    def metadata?(address)
      ip = IPAddr.new(address.to_s).native
      METADATA.any? { |range| range.family == ip.family && range.include?(ip) }
    rescue IPAddr::Error
      false
    end
  end
end
