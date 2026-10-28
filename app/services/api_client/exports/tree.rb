module ApiClient
  module Exports
    # A collection's folders and requests in sidebar order, loaded in two queries and walked from the root.
    class Tree
      def initialize(collection)
        @folders = collection.folders.order(:position, :created_at).group_by(&:parent_id)
        @requests = collection.api_requests.order(:position, :created_at).group_by(&:folder_id)
      end

      def folders_in(folder = nil)
        @folders.fetch(folder&.id, [])
      end

      def requests_in(folder = nil)
        @requests.fetch(folder&.id, [])
      end
    end
  end
end
