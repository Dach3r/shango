module Projects
  module Environments
    class Update
      include Serviceable

      def initialize(environment:, attributes:)
        @environment = environment
        @attributes = attributes
      end

      private

      def perform
        @environment.assign_attributes(Normalize.call(attributes: @attributes))
        @environment.save ? Result.success(@environment) : Result.failure(@environment)
      end
    end
  end
end
