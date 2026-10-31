module ApiClient
  module Collections
    class Create
      include Serviceable

      def initialize(project:, creator:, attributes:)
        @project = project
        @creator = creator
        @attributes = attributes.to_h.symbolize_keys
      end

      private

      def perform
        collection = @project.collections.new(@attributes.slice(:name, :description).merge(creator: @creator))
        return Result.failure(collection) unless collection.save

        AuditEvents::Record.call(project: @project, kind: :collection_created, actor: @creator, name: collection.name)
        Result.success(collection)
      end
    end
  end
end
