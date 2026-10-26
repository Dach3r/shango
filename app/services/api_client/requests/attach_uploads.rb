module ApiClient
  module Requests
    # Stores files submitted with a request form (multipart rows and the binary body) and links them
    # from `body_form`. Must run on a persisted request. Files no longer referenced are purged.
    class AttachUploads
      include Serviceable

      def initialize(api_request:, uploads: {}, binary_upload: nil)
        @api_request = api_request
        @uploads = uploads.to_h.compact_blank
        @binary_upload = binary_upload
      end

      private

      def perform
        rows = @api_request.body_form.map(&:dup)
        @uploads.each { |token, file| attach_to_row(rows, token, file) }
        rows.each { |row| row.delete("upload_token") }
        @api_request.body_form = rows
        replace_binary_body if @binary_upload.present?
        purge_unreferenced(rows)
        @api_request
      end

      def attach_to_row(rows, token, file)
        row = rows.find { |candidate| candidate["upload_token"] == token } or return
        attachment = ActiveStorage::Attachment.create!(name: "body_files", record: @api_request, blob: upload_blob(file))
        row.merge!("type" => "file", "attachment_id" => attachment.id.to_s, "value" => file.original_filename)
      end

      def replace_binary_body
        ActiveStorage::Attachment.where(name: "binary_body", record: @api_request).find_each(&:purge_later)
        ActiveStorage::Attachment.create!(name: "binary_body", record: @api_request, blob: upload_blob(@binary_upload))
      end

      def upload_blob(file)
        ActiveStorage::Blob.create_and_upload!(io: file.tempfile, filename: file.original_filename, content_type: file.content_type)
      end

      def purge_unreferenced(rows)
        referenced = rows.filter_map { |row| row["attachment_id"].presence }
        ActiveStorage::Attachment.where(name: "body_files", record: @api_request).find_each do |attachment|
          attachment.purge_later unless referenced.include?(attachment.id.to_s)
        end
      end
    end
  end
end
