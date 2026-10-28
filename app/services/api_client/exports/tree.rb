module ApiClient
  module Exports
    # A collection's folders and requests in sidebar order, loaded in two queries and walked from the root.
    # Every exporter asks for each folder's requests once, which is what drives the progress.
    class Tree
      def initialize(collection, progress: nil)
        @folders = collection.folders.order(:position, :created_at).group_by(&:parent_id)
        @requests = collection.api_requests.order(:position, :created_at).group_by(&:folder_id)
        @progress = progress
      end

      def folders_in(folder = nil)
        @folders.fetch(folder&.id, [])
      end

      def requests_in(folder = nil)
        requests = @requests.fetch(folder&.id, [])
        @progress&.advance(requests.size)
        requests
      end
    end
  end
end
