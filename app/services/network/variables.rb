module Network
  # Resolves `{{variables}}` in text typed into a network tool from the selected environment (and the `{{$...}}`
  # helpers). Secret variables are refused so their values never end up in results, history or logs.
  class Variables
    include Serviceable

    def initialize(raw:, environment: nil)
      @raw = raw.to_s
      @environment = environment
    end

    private

    def perform
      variables = @environment ? @environment.variables.select(&:enabled) : []
      resolver = ApiClient::VariableResolver.new(variables.reject(&:secret).to_h { |variable| [variable.key, variable.value.to_s] })
      text = resolver.resolve(@raw)
      return Result.success(text) if resolver.unresolved.empty?

      name = resolver.unresolved.first
      secret = variables.any? { |variable| variable.secret && variable.key == name }
      Result.failure(error: secret ? :secret_variable : :unresolved_variable, name:)
    end
  end
end
