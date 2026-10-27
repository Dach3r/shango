module Workbench
  class RequestsController < BaseController
    include RequestParameters

    before_action :set_collection, only: %i[new create]
    before_action :set_api_request, only: %i[show update destroy]

    def show
      ApiClient::Tabs::Open.call(api_request: @api_request, user: current_user) unless prefetch?
      @execution = RequestExecution.latest_for(@api_request, current_user)
      restore_stash
    end

    def new
      @api_request = @collection.api_requests.new(folder_id: params[:folder_id], name: t(".default_name"))
    end

    def create
      result = ApiClient::Requests::Create.call(collection: @collection, attributes: request_attributes)
      return redirect_to(workbench_request_path(result.record), status: :see_other) if result.success?

      @api_request = result.record
      render_form_errors
    end

    def update
      result = ApiClient::Requests::Update.call(api_request: @api_request, attributes: request_attributes, uploads: request_uploads, binary_upload:)
      clear_stash if result.success?
      return render_placement if result.success? && @api_request.draft? && params[:place].present?
      return redirect_to(workbench_request_path(@api_request), status: :see_other) if result.success?

      @execution = RequestExecution.latest_for(@api_request, current_user)
      render :show, status: :unprocessable_entity
    end

    def destroy
      ApiClient::Requests::Destroy.call(api_request: @api_request)
      clear_stash
      redirect_to workbench_root_path, status: :see_other
    end

    private

    def clear_stash
      ApiClient::Requests::Stash.clear(api_request: @api_request, user: current_user)
    end

    # Puts the unsaved edits kept for this tab back on the (unsaved) record.
    def restore_stash
      stash = ApiClient::Requests::Stash.read(api_request: @api_request, user: current_user)
      return unless stash

      ApiClient::Requests::Assign.call(api_request: @api_request, attributes: stash)
      @unsaved = true
    end

    # Browser speculative loads must not open tabs: showing the request is a side effect only a real visit should have.
    def prefetch?
      [request.headers["Sec-Purpose"], request.headers["X-Sec-Purpose"]].any? { |purpose| purpose.to_s.include?("prefetch") }
    end

    # Saving a draft asks where it should go; the edits are already persisted, so closing the modal keeps it as a draft.
    def render_placement
      render turbo_stream: turbo_stream.update("modal", partial: "workbench/requests/placements/form")
    end

    def set_collection
      @collection = current_project.collections.find(params[:collection_id])
    end

    def set_api_request
      @api_request = current_project.api_requests.visible_to(current_user).find(params[:id])
    end
  end
end
