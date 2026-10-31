module ApiClient
  module Runs
    # Plans a run of a collection (or one folder): one pending item per request, in sidebar order, and queues the job that sends them.
    # Result#record is the CollectionRun; a failure carries `error` (:already_running, :empty, :too_many).
    class Create
      include Serviceable

      ACTIVE_WINDOW = 1.hour

      def initialize(collection:, user:, folder: nil, environment: nil, options: {})
        @collection = collection
        @folder = folder
        @user = user
        @environment = environment
        @options = options.to_h.stringify_keys
      end

      private

      def perform
        return Result.failure(error: :already_running) if running?

        requests = Scope.call(collection: @collection, folder: @folder).record
        return Result.failure(error: :empty) if requests.empty?
        return Result.failure(error: :too_many, max: CollectionRun.max_requests) if requests.size > CollectionRun.max_requests

        run = plan(requests)
        RunCollectionJob.perform_later(run.id)
        Result.success(run)
      end

      def running?
        CollectionRun.active.where(project_id: @collection.project_id, user_id: @user.id, updated_at: ACTIVE_WINDOW.ago..).exists?
      end

      def plan(requests)
        CollectionRun.transaction do
          run = CollectionRun.create!(
            project: @collection.project, collection: @collection, folder: @folder, user: @user, environment: @environment,
            total_count: requests.size, options: normalized_options
          )
          rows = requests.each_with_index.map { |request, index| { collection_run_id: run.id, api_request_id: request.id, request_name: request.name, http_method: request.http_method, position: index } }
          CollectionRunItem.insert_all!(rows)
          run
        end
      end

      def normalized_options
        {
          "stop_on_failure" => flag("stop_on_failure"),
          "persist_variables" => flag("persist_variables"),
          "delay_ms" => @options["delay_ms"].to_i.clamp(0, CollectionRun::MAX_DELAY_MS)
        }
      end

      def flag(name)
        ActiveModel::Type::Boolean.new.cast(@options[name]) == true
      end
    end
  end
end
