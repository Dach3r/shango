module Projects
  module Environments
    class CreateVariable
      include Serviceable

      def initialize(environment:, key:, value:)
        @environment = environment
        @key = key
        @value = value
      end

      private

      def perform
        variable = @environment.variables.find_or_initialize_by(key: @key)
        variable.assign_attributes(value: @value, enabled: true)
        variable.save ? Result.success(variable) : Result.failure(variable)
      end
    end
  end
end
