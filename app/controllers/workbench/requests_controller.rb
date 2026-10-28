module Workbench
  class RequestsController < BaseController
    include RequestParameters

    before_action :set_collection, only: %i[new create]
    before_action :set_api_request, only: %i[show update destroy]

    def show
      authorize @api_request
      ApiClient::Tabs::Open.call(api_request: @api_request, user: current_user) unless prefetch?
      @execution = RequestExecution.unsaved_for(@api_request, current_user)
      @unsaved = ApiClient::Drafts::Apply.call(api_request: @api_request, user: current_user)
    end

    def new
      @api_request = @collection.api_requests.new(folder_id: params[:folder_id], name: t(".default_name"))
      authorize @api_request
    end

    def create
      authorize @collection.api_requests.new
      result = ApiClient::Requests::Create.call(collection: @collection, attributes: request_attributes)
      return redirect_to(workbench_request_path(result.record), status: :see_other) if result.success?

      @api_request = result.record
      render_form_errors
    end

    def update
      authorize @api_request
      return update_draft if @api_request.draft?

      result = ApiClient::Requests::Update.call(api_request: @api_request, attributes: request_attributes, uploads: request_uploads, binary_upload:)
      ApiClient::Drafts::Discard.call(api_request: @api_request, user: current_user) if result.success?
      return redirect_to(workbench_request_path(@api_request), status: :see_other) if result.success?

      @execution = RequestExecution.unsaved_for(@api_request, current_user)
      render :show, status: :unprocessable_entity
    end

    def destroy
      authorize @api_request
      if @api_request.draft?
        ApiClient::Drafts::Discard.call(api_request: @api_request, user: current_user)
      else
        ApiClient::Requests::Destroy.call(api_request: @api_request)
      end
      redirect_to workbench_root_path, status: :see_other
    end

    private

    # A new request is not written to the database by saving it: the edits are kept as its draft and the user is asked
    # where it goes (see Requests::PlacementsController, which is what actually saves it).
    def update_draft
      saved = ApiClient::Drafts::Save.call(api_request: @api_request, user: current_user, attributes: request_attributes)
      return render_placement if saved.success?

      ApiClient::Requests::Assign.call(api_request: @api_request, attributes: request_attributes)
      @api_request.errors.add(:base, :draft_too_large)
      @execution = RequestExecution.unsaved_for(@api_request, current_user)
      render :show, status: :unprocessable_entity
    end

    # Browser speculative loads must not open tabs: showing the request is a side effect only a real visit should have.
    def prefetch?
      [request.headers["Sec-Purpose"], request.headers["X-Sec-Purpose"]].any? { |purpose| purpose.to_s.include?("prefetch") }
    end

    # Saving a draft asks where it should go; the edits are kept as its draft, so closing the modal keeps it as a draft.
    def render_placement
      render turbo_stream: turbo_stream.update("modal", partial: "workbench/requests/placements/form")
    end

    def set_collection
      @collection = current_project.collections.find(params[:collection_id])
    end

    def set_api_request
      @api_request = ApiClient::Drafts::Resolve.call(project: current_project, user: current_user, id: params[:id])
    end
  end
end
