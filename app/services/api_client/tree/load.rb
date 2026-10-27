module ApiClient
  module Tree
    # Everything the workspace sidebar needs, in three queries (no request bodies are loaded).
    class Load
      include Serviceable

      Branch = Struct.new(:collection, :folders, :requests, keyword_init: true) do
        def root_folders
          folders[nil].to_a
        end

        def children_of(folder)
          folders[folder.id].to_a
        end

        def requests_in(folder = nil)
          requests[folder&.id].to_a
        end

        def all_requests
          requests.values.flatten
        end

        def folder(id)
          folder_index[id]
        end

        # Folders from the collection root down to the folder with this id (itself included).
        def folder_path(id)
          path = []
          node = folder(id)
          while node && path.exclude?(node)
            path.unshift(node)
            node = folder(node.parent_id)
          end
          path
        end

        private

        def folder_index
          @folder_index ||= folders.values.flatten.index_by(&:id)
        end
      end

      FOLDER_COLUMNS = %i[id collection_id parent_id name position created_at].freeze
      REQUEST_COLUMNS = %i[id name http_method collection_id folder_id position created_at project_id].freeze

      def initialize(project:)
        @project = project
      end

      private

      def perform
        folders = @project.folders.select(*FOLDER_COLUMNS).order(:position, :created_at).group_by(&:collection_id)
        requests = @project.api_requests.select(*REQUEST_COLUMNS).order(:position, :created_at).group_by(&:collection_id)

        @project.collections.ordered.map do |collection|
          Branch.new(
            collection:,
            folders: folders.fetch(collection.id, []).group_by(&:parent_id),
            requests: requests.fetch(collection.id, []).group_by(&:folder_id)
          )
        end
      end
    end
  end
end
