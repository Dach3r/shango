module Projects
  module Cookies
    class Create
      include Serviceable

      def initialize(project:, environment:, attributes:)
        @project = project
        @environment = environment
        @attributes = attributes
      end

      private

      def perform
        cookie = Cookie.for_jar(@project, @environment).new(Normalize.call(attributes: @attributes))
        return Result.failure(cookie) unless cookie.save

        Cookie.trim(@project, @environment)
        Result.success(cookie)
      end
    end
  end
end
