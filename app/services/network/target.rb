module Network
  # Turns what the user typed into a host: resolves `{{variables}}` from the selected environment and validates it.
  # Secret variables are refused so their values never end up in results or logs.
  class Target
    include Serviceable

    LABEL = /\A[a-z0-9_]([a-z0-9_-]{0,61}[a-z0-9_])?\z/
    MAX_LENGTH = 253

    def initialize(raw:, environment: nil)
      @raw = raw.to_s
      @environment = environment
    end

    private

    def perform
      variables = @environment ? @environment.variables.select(&:enabled) : []
      resolver = ApiClient::VariableResolver.new(variables.reject(&:secret).to_h { |variable| [variable.key, variable.value.to_s] })
      host = resolver.resolve(@raw).strip.downcase.delete_suffix(".")

      return failure_for_variable(resolver.unresolved.first, variables) if resolver.unresolved.any?
      return Result.failure(error: :blank) if host.empty?
      return Result.failure(error: :invalid) unless valid?(host)

      Result.success(host)
    end

    def failure_for_variable(name, variables)
      secret = variables.any? { |variable| variable.secret && variable.key == name }
      Result.failure(error: secret ? :secret_variable : :unresolved_variable, name:)
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
