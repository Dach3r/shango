module ApiClient
  module Requests
    # The assertions and extractors that apply to a request: those of its collection, then of its folders (outermost first),
    # then its own, so a rule set once on a folder covers everything below it. Result#record is
    # `{ assertions: [...], extractors: [...] }`, rows in that order.
    class Automation
      include Serviceable

      def initialize(api_request:)
        @api_request = api_request
      end

      private

      def perform
        levels = [@api_request.collection, *folders, @api_request].compact
        Result.success({ assertions: levels.flat_map(&:assertions), extractors: levels.flat_map(&:extractors) })
      end

      def folders
        folder = @api_request.folder
        folder ? [*folder.ancestors.reverse, folder] : []
      end
    end
  end
end
