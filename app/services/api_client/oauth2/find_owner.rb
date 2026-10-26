module ApiClient
  module Oauth2
    # Resolves the record that stores OAuth settings, always inside the given project.
    class FindOwner
      include Serviceable

      OWNERS = { "Collection" => :collections, "Folder" => :folders, "ApiRequest" => :api_requests }.freeze

      def initialize(project:, user:, type:, id:)
        @project = project
        @user = user
        @type = type.to_s
        @id = id
      end

      private

      def perform
        association = OWNERS[@type] or raise ActiveRecord::RecordNotFound
        scope = @project.public_send(association)
        scope = scope.visible_to(@user) if association == :api_requests
        owner = scope.find(@id)
        raise ActiveRecord::RecordNotFound unless owner.auth_type == "oauth2"

        owner
      end
    end
  end
end
