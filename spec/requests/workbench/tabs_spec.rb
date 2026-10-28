require "rails_helper"

RSpec.describe "Workbench tabs" do
  include_context "with workbench project"

  let(:second) { create(:api_request, collection:) }
  let(:third) { create(:api_request, collection:) }

  before do
    [api_request, second, third].each { |request| get workbench_request_path(request) }
  end

  def open_ids
    RequestTab.where(user:).pluck(:api_request_id)
  end

  it "closes the tabs to the left and stays on the current one", :aggregate_failures do
    delete workbench_tabs_path(side: "left", request_id: second.id, current: third.id)

    expect(open_ids).to contain_exactly(second.id, third.id)
    expect(response).to redirect_to(workbench_request_path(third))
  end

  it "closes the tabs to the right and falls back to the last remaining one", :aggregate_failures do
    delete workbench_tabs_path(side: "right", request_id: second.id, current: third.id)

    expect(open_ids).to contain_exactly(api_request.id, second.id)
    expect(response).to redirect_to(workbench_request_path(second))
  end

  it "closes all tabs", :aggregate_failures do
    delete workbench_tabs_path(side: "all", current: second.id)

    expect(open_ids).to be_empty
    expect(response).to redirect_to(workbench_root_path)
  end

  it "ignores unknown sides and tabs", :aggregate_failures do
    delete workbench_tabs_path(side: "up", request_id: second.id)
    delete workbench_tabs_path(side: "left", request_id: foreign_request.id)

    expect(open_ids.size).to eq(3)
  end

  describe "edge cases" do
    it "only closes the tabs of the current user", :aggregate_failures do
      other_tab = create(:request_tab, api_request: second)
      delete workbench_tabs_path(side: "all")

      expect(open_ids).to be_empty
      expect(RequestTab.where(id: other_tab.id)).to exist
    end

    it "does not touch tabs of other projects for a foreign pivot", :aggregate_failures do
      foreign_tab = create(:request_tab, api_request: foreign_request)
      delete workbench_tabs_path(side: "right", request_id: foreign_request.id)

      expect(RequestTab.where(id: foreign_tab.id)).to exist
      expect(open_ids.size).to eq(3)
    end

    it "closes nothing without a side or a pivot", :aggregate_failures do
      delete workbench_tabs_path
      delete workbench_tabs_path(side: "right")

      expect(open_ids.size).to eq(3)
    end

    it "closes nothing to the left of the first tab and nothing to the right of the last", :aggregate_failures do
      delete workbench_tabs_path(side: "left", request_id: api_request.id)
      delete workbench_tabs_path(side: "right", request_id: third.id)

      expect(open_ids.size).to eq(3)
    end

    it "falls back to the last tab when current is unknown or foreign", :aggregate_failures do
      delete workbench_tabs_path(side: "left", request_id: second.id, current: foreign_request.id)

      expect(response).to redirect_to(workbench_request_path(third))
    end

    it "discards drafts when closing all", :aggregate_failures do
      untouched = ApiClient::Drafts::Create.call(project:, user:).record
      edited = ApiClient::Drafts::Create.call(project:, user:).record
      edited.update!(name: "Edited")

      delete workbench_tabs_path(side: "all")

      expect(RequestDraft.where(id: [untouched.id, edited.id])).not_to exist
    end

    it "keeps the tabs the user declined to close", :aggregate_failures do
      edited = ApiClient::Drafts::Create.call(project:, user:).record
      edited.update!(name: "Edited")

      delete workbench_tabs_path(side: "all", keep: [edited.id, second.id], current: edited.id)

      expect(open_ids.compact).to contain_exactly(second.id)
      expect(RequestTab.where(user:, request_draft: edited)).to exist
      expect(RequestDraft.where(id: edited.id)).to exist
      expect(response).to redirect_to(workbench_request_path(edited))
    end

    it "requires authentication" do
      sign_out user
      delete workbench_tabs_path(side: "all")

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
