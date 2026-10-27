module Shango
  # File storage backend for uploads: the local disk by default, S3 (or any S3-compatible store) when the operator
  # sets SHANGO_STORAGE=s3. The local disk only works with a single app server.
  module Storage
    SERVICES = %w[local s3].freeze

    class << self
      def service
        name = ENV.fetch("SHANGO_STORAGE", "local")
        SERVICES.include?(name) ? name.to_sym : raise(ArgumentError, "SHANGO_STORAGE must be one of #{SERVICES.join(", ")} (got #{name.inspect})")
      end
    end
  end
end
