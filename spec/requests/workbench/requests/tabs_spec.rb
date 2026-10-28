require "rails_helper"

RSpec.describe "Workbench request tabs" do
  include_context "with workbench project"

  let(:other_request) { create(:api_request, collection:) }

  before do
    get workbench_request_path(api_request)
    get workbench_request_path(other_request)
  end

  it "opens a tab when a request is shown", :aggregate_failures do
    expect(RequestTab.where(user:).count).to eq(2)
    expect(response.body).to include(workbench_request_tab_path(api_request))
  end

  it "closes a background tab and stays on the page", :aggregate_failures do
    delete workbench_request_tab_path(api_request)

    expect(response).to redirect_to(workbench_root_path)
    expect(RequestTab.where(user:, api_request:)).not_to exist
    expect(api_request.reload).to be_persisted
  end

  it "moves to the last open tab when closing the current one" do
    delete workbench_request_tab_path(other_request, current: true)

    expect(response).to redirect_to(workbench_request_path(api_request))
  end

  it "goes back to the workbench when no tabs remain" do
    delete workbench_request_tab_path(api_request)
    delete workbench_request_tab_path(other_request, current: true)

    expect(response).to redirect_to(workbench_root_path)
  end

  it "does not close tabs of requests from other projects" do
    delete workbench_request_tab_path(foreign_request)

    expect(response).to have_http_status(:not_found)
  end

  describe "edge cases" do
    it "keeps a single tab when a request is opened repeatedly" do
      3.times { get workbench_request_path(api_request) }

      expect(RequestTab.where(user:, api_request:).count).to eq(1)
    end

    it "closing a tab that is not open is harmless", :aggregate_failures do
      delete workbench_request_tab_path(api_request)
      delete workbench_request_tab_path(api_request)

      expect(response).to redirect_to(workbench_root_path)
      expect(api_request.reload).to be_persisted
    end

    it "only closes the tab of the current user", :aggregate_failures do
      other_user_tab = create(:request_tab, api_request:)
      delete workbench_request_tab_path(api_request)

      expect(RequestTab.where(id: other_user_tab.id)).to exist
      expect(RequestTab.where(user:, api_request:)).not_to exist
    end

    it "does not close tabs of other users' drafts", :aggregate_failures do
      other_tab = create(:request_tab, user: other_draft.user, api_request: nil, request_draft: other_draft)
      delete workbench_request_tab_path(other_draft)

      expect(response).to have_http_status(:not_found)
      expect(RequestTab.where(id: other_tab.id)).to exist
    end

    it "discards a new draft when its tab is closed", :aggregate_failures do
      delete workbench_request_tab_path(draft)

      expect(RequestDraft.where(id: draft.id)).not_to exist
      expect(RequestTab.where(request_draft_id: draft.id)).not_to exist
    end

    it "redirects to the last remaining tab when the current one is closed and others stay", :aggregate_failures do
      third = create(:api_request, collection:)
      get workbench_request_path(third)
      delete workbench_request_tab_path(other_request, current: other_request.id)

      expect(response).to redirect_to(workbench_request_path(third))
    end

    it "requires authentication" do
      sign_out user
      delete workbench_request_tab_path(api_request)

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
