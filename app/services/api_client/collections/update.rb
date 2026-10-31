module ApiClient
  module Collections
    class Update
      include Serviceable

      def initialize(collection:, attributes:, actor: nil)
        @collection = collection
        @attributes = attributes.to_h.symbolize_keys
        @actor = actor
      end

      private

      def perform
        @collection.assign_attributes(@attributes.slice(:name, :description, :assertions, :extractors, :pre_request_script, :post_response_script))
        return Result.failure(@collection) unless @collection.save

        AuditEvents::Record.call(project: @collection.project, kind: :collection_updated, actor: @actor, name: @collection.name) if @collection.saved_changes?
        Result.success(@collection)
      end
    end
  end
end
