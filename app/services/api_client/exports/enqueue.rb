module ApiClient
  module Exports
    # Records an export request and queues the job that builds it. Result#record is the CollectionExport.
    class Enqueue
      include Serviceable

      def initialize(collection:, user:, format:, include_environments: false, include_credentials: false)
        @collection = collection
        @user = user
        @format = format.to_s
        @include_environments = include_environments
        @include_credentials = include_credentials
      end

      private

      def perform
        return Result.failure(error: I18n.t("workbench.exports.errors.unknown_format")) unless Export::FORMATS.map(&:to_s).include?(@format)

        export = CollectionExport.create!(
          project: @collection.project, collection: @collection, user: @user, export_format: @format,
          include_environments: @include_environments, include_credentials: @include_credentials, expires_at: CollectionExport.retention.from_now
        )
        ExportCollectionJob.perform_later(@user.id, export.id)
        Result.success(export)
      end
    end
  end
end
