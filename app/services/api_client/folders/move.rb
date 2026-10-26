module ApiClient
  module Folders
    # Moves a folder under another folder (or to the collection root) of the same collection.
    class Move
      include Serviceable

      def initialize(folder:, parent_id: nil, before_id: nil)
        @folder = folder
        @parent_id = parent_id.presence
        @before_id = before_id.presence
      end

      private

      def perform
        @folder.parent = @parent_id && @folder.collection.folders.find(@parent_id)
        return Result.failure(@folder) unless @folder.save

        Tree::Reposition.call(record: @folder, siblings: @folder.siblings, before_id: @before_id)
        Result.success(@folder)
      end
    end
  end
end
