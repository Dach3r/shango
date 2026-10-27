module Projects
  module Cookies
    # Turns the submitted cookie form into model attributes: a lowercase domain without the leading dot, a default path
    # and a blank expiry meaning a session cookie.
    class Normalize
      include Serviceable

      def initialize(attributes:)
        @attributes = attributes.to_h.symbolize_keys
      end

      private

      def perform
        attributes = @attributes.dup
        attributes[:name] = attributes[:name].to_s.strip if attributes.key?(:name)
        attributes[:domain] = attributes[:domain].to_s.strip.delete_prefix(".").downcase if attributes.key?(:domain)
        attributes[:path] = attributes[:path].to_s.strip.presence || "/" if attributes.key?(:path)
        attributes[:expires_at] = attributes[:expires_at].presence if attributes.key?(:expires_at)
        attributes
      end
    end
  end
end
