require "rails_helper"

RSpec.describe "Workbench smoke", :system do
  let(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:membership) { create(:membership, :owner, user:, project:) }
  let(:collection) { create(:collection, project:, name: "Pets API") }
  let!(:api_request) { create(:api_request, collection:, name: "List pets") }

  before do
    user.update!(current_membership: membership)
    login_as user, scope: :user
  end

  it "opens a request from the sidebar as a tab" do
    visit workbench_root_path
    click_link "List pets"

    expect(page).to have_current_path(workbench_request_path(api_request))
    expect(page).to have_field("api_request[url]", visible: :all, with: api_request.url)
  end
end
