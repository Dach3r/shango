module ApiClient
  module Executions
    # The user's saved executions in a project, newest first and grouped by collection (drafts last).
    class History
      include Serviceable

      Group = Struct.new(:collection, :executions, keyword_init: true)

      LIMIT = 200
      COLUMNS = %i[id api_request_id environment_id http_method url status status_text error_kind duration_ms created_at].freeze

      def initialize(project:, user:)
        @project = project
        @user = user
      end

      private

      def perform
        by_collection = executions.group_by { |execution| execution.api_request.collection_id }
        groups = @project.collections.ordered.filter_map do |collection|
          Group.new(collection:, executions: by_collection[collection.id]) if by_collection[collection.id]
        end
        groups << Group.new(collection: nil, executions: by_collection[nil]) if by_collection[nil]
        groups
      end

      def executions
        @project.request_executions.where(user: @user).merge(ApiRequest.visible_to(@user))
                .joins(:api_request).select(*COLUMNS.map { |column| "request_executions.#{column}" })
                .includes(:environment, :api_request).recent.limit(LIMIT)
      end
    end
  end
end
