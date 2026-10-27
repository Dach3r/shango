module ApiClient
  module Requests
    class Update
      include Serviceable

      MAX_FILE_MB = 10
      MAX_TOTAL_MB = 25
      MAX_FILES = 10

      def initialize(api_request:, attributes:, uploads: {}, binary_upload: nil)
        @api_request = api_request
        @attributes = attributes
        @uploads = uploads
        @binary_upload = binary_upload
      end

      private

      def perform
        Assign.call(api_request: @api_request, attributes: @attributes)
        return Result.failure(@api_request) unless uploads_within_limits?

        AttachUploads.call(api_request: @api_request, uploads: @uploads, binary_upload: @binary_upload)
        @api_request.save ? Result.success(@api_request) : Result.failure(@api_request)
      end

      # Limits come from SHANGO_MAX_UPLOAD_MB (per file), SHANGO_MAX_UPLOADS_TOTAL_MB and SHANGO_MAX_UPLOADS (per submission).
      def uploads_within_limits?
        files = [*@uploads.values, @binary_upload].compact_blank
        max_file = limit("SHANGO_MAX_UPLOAD_MB", MAX_FILE_MB)
        max_total = limit("SHANGO_MAX_UPLOADS_TOTAL_MB", MAX_TOTAL_MB)
        max_files = limit("SHANGO_MAX_UPLOADS", MAX_FILES)

        oversized = files.find { |file| file.size > max_file.megabytes }
        if oversized
          @api_request.errors.add(:base, :upload_too_large, name: oversized.original_filename, max: max_file)
        elsif files.sum(&:size) > max_total.megabytes
          @api_request.errors.add(:base, :uploads_too_large, max: max_total)
        elsif files.size > max_files
          @api_request.errors.add(:base, :too_many_uploads, max: max_files)
        end
        @api_request.errors.empty?
      end

      def limit(variable, default)
        value = ENV[variable].to_i
        value.positive? ? value : default
      end
    end
  end
end
