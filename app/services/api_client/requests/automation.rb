module ApiClient
  module Requests
    # The assertions, extractors and scripts that apply to a request: those of its collection, then of its folders (outermost first),
    # then its own, so a rule set once on a folder covers everything below it. Result#record is
    # `{ assertions:, extractors:, pre_scripts:, post_scripts: }`; the first two are rows in that order, the scripts are
    # Scripting::Run::Script entries (blank scripts left out).
    class Automation
      include Serviceable

      LEVELS = { "Collection" => :collection, "Folder" => :folder, "ApiRequest" => :request }.freeze

      def initialize(api_request:)
        @api_request = api_request
      end

      private

      def perform
        levels = [@api_request.collection, *folders, @api_request].compact
        Result.success({
          assertions: levels.flat_map(&:assertions), extractors: levels.flat_map(&:extractors),
          pre_scripts: scripts(levels, :pre_request_script), post_scripts: scripts(levels, :post_response_script)
        })
      end

      def folders
        folder = @api_request.folder
        folder ? [*folder.ancestors.reverse, folder] : []
      end

      def scripts(levels, column)
        levels.filter_map do |record|
          source = record.public_send(column)
          Scripting::Run::Script.new(level: LEVELS.fetch(record.class.name), name: record.name, source:) if source.present?
        end
      end
    end
  end
end
