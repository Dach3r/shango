module Projects
  module Cookies
    class Update
      include Serviceable

      def initialize(cookie:, attributes:)
        @cookie = cookie
        @attributes = attributes
      end

      private

      def perform
        @cookie.assign_attributes(Normalize.call(attributes: @attributes))
        @cookie.save ? Result.success(@cookie) : Result.failure(@cookie)
      end
    end
  end
end
