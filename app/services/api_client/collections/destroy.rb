module ApiClient
  module Collections
    class Destroy
      include Serviceable

      def initialize(collection:, actor: nil)
        @collection = collection
        @actor = actor
      end

      private

      def perform
        return Result.failure(@collection) unless @collection.destroy

        AuditEvents::Record.call(project: @collection.project, kind: :collection_deleted, actor: @actor, name: @collection.name)
        Result.success(@collection)
      end
    end
  end
end
