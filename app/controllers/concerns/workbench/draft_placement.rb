module Workbench
  # A collection or folder created while a new request is being saved: it carries the draft and the name typed so far
  # and returns to the placement dialog afterwards (see Requests::PlacementsController).
  module DraftPlacement
    extend ActiveSupport::Concern

    private

    def load_placement
      @draft = draft_to_place
      @placement = params[:placement].present?
      @request_name = params[:request_name]
    end

    def draft_to_place
      return if params[:draft_id].blank?

      draft = ApiClient::Drafts::Resolve.call(project: current_project, user: current_user, id: params[:draft_id])
      raise ActiveRecord::RecordNotFound unless draft.draft?

      draft
    end

    def placement_path(destination = nil)
      new_workbench_request_placement_path(@draft, destination:, request_name: @request_name)
    end
  end
end
