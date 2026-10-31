module ApiClient
  module Runs
    # The requests a run covers, in the order the sidebar shows them: for each container, its subfolders (recursively) first
    # and then its own requests. Result#record is a list of ApiRequest with only the columns a run needs.
    class Scope
      include Serviceable

      def initialize(collection:, folder: nil)
        @collection = collection
        @folder = folder
      end

      private

      def perform
        @folders = @collection.folders.order(:position, :created_at).pluck(:id, :parent_id).group_by(&:last).transform_values { |pairs| pairs.map(&:first) }
        @requests = @collection.api_requests.order(:position, :created_at).select(:id, :name, :http_method, :folder_id).group_by(&:folder_id)
        Result.success(walk(@folder&.id))
      end

      def walk(folder_id)
        @folders.fetch(folder_id, []).flat_map { |child| walk(child) } + @requests.fetch(folder_id, [])
      end
    end
  end
end
