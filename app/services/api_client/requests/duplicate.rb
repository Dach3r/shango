module ApiClient
  module Requests
    class Duplicate
      include Serviceable

      def initialize(api_request:)
        @api_request = api_request
      end

      private

      def perform
        copy = @api_request.dup
        copy.name = I18n.t("api_client.requests.copy_name", name: @api_request.name)
        copy.position = 0
        copy.save!

        mapping = {}
        ActiveStorage::Attachment.where(record: @api_request).find_each do |attachment|
          clone = ActiveStorage::Attachment.create!(name: attachment.name, record: copy, blob: attachment.blob)
          mapping[attachment.id.to_s] = clone.id.to_s if attachment.name == "body_files"
        end
        copy.update!(body_form: copy.body_form.map { |row| row["attachment_id"] ? row.merge("attachment_id" => mapping[row["attachment_id"]]) : row })

        Result.success(copy)
      end
    end
  end
end
