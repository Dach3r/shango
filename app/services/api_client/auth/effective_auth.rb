module ApiClient
  module Auth
    # Finds the authentication that applies to a request: its own, or the nearest
    # folder/collection above it that does not inherit.
    class EffectiveAuth
      include Serviceable

      Resolved = Struct.new(:type, :config, :owner, keyword_init: true)

      def initialize(api_request:)
        @api_request = api_request
      end

      private

      def perform
        owner = chain.find { |node| !node.inherits_auth? } || @api_request.collection
        Resolved.new(type: owner.auth_type, config: owner.auth_config, owner:)
      end

      def chain
        folders = @api_request.folder ? [@api_request.folder, *@api_request.folder.ancestors] : []
        [@api_request, *folders, @api_request.collection]
      end
    end
  end
end
