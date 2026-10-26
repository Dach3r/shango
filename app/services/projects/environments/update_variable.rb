module Projects
  module Environments
    class UpdateVariable
      include Serviceable

      def initialize(variable:, value:)
        @variable = variable
        @value = value
      end

      private

      def perform
        @variable.value = @value
        @variable.save ? Result.success(@variable) : Result.failure(@variable)
      end
    end
  end
end
