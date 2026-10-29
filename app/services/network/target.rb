module Network
  class Target
    include Serviceable

    LABEL = /\A[a-z0-9_]([a-z0-9_-]{0,61}[a-z0-9_])?\z/
    MAX_LENGTH = 253
    SCHEME = %r{\Ahttps?://}

    def initialize(raw:, environment: nil)
      @raw = raw.to_s
      @environment = environment
    end

    private

    def perform
      resolved = Variables.call(raw: @raw, environment: @environment)
      return resolved if resolved.failure?

      host = bare_host(resolved.record)
      return Result.failure(error: :blank) if host.empty?
      return Result.failure(error: :invalid) unless valid?(host)

      Result.success(host)
    end

    def bare_host(value)
      value.strip.downcase.delete_prefix(value.strip.downcase[SCHEME].to_s).split(%r{[/?#]}, 2).first.to_s.delete_suffix(".")
    end

    def valid?(host)
      return true if ip?(host)

      host.length <= MAX_LENGTH && host.split(".", -1).all? { |label| label.match?(LABEL) }
    end

    def ip?(host)
      IPAddr.new(host)
      true
    rescue IPAddr::Error
      false
    end
  end
end
