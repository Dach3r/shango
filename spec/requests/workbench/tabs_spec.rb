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
end
