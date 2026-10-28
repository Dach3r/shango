module ApiClient
  module Drafts
    # Copies a new draft into another draft tab, edits and settings included. Nothing reaches `api_requests`.
    class Duplicate
      include Serviceable

      def initialize(api_request:, user:)
        @api_request = api_request
        @user = user
      end

      private

      def perform
        source = @user.request_drafts.where(project: @api_request.project, api_request_id: nil).find(@api_request.id)
        name = I18n.t("workbench.requests.copy_name", name: source.name)
        copy = source.dup
        copy.data = source.data.merge("name" => name)
        copy.name = name

        ApplicationRecord.transaction do
          copy.save!
          RequestTab.create!(user: @user, request_draft: copy)
        end
        Result.success(copy)
      end
    end
  end
end
