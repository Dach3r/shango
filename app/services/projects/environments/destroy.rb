module Projects
  module Environments
    class Destroy
      include Serviceable

      def initialize(environment:)
        @environment = environment
      end

      private

      def perform
        @environment.destroy ? Result.success(@environment) : Result.failure(@environment)
      end
    end
  end
end
