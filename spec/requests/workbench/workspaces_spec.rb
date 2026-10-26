require "rails_helper"

RSpec.describe "Workbench workspace" do
  include_context "with workbench project"

  it "requires sign in" do
    sign_out user
    get workbench_root_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "renders the tree without an environment" do
    folder
    create(:api_request, collection:, folder:)
    get workbench_root_path

    expect(response.body).to include(collection.name, folder.name)
  end

  it "opens the last open tab instead of the empty state" do
    create(:request_tab, user:, api_request:)
    last = create(:api_request, collection:)
    create(:request_tab, user:, api_request: last)
    get workbench_root_path

    expect(response).to redirect_to(workbench_request_path(last))
  end

  it "offers the selected environment's variables", :aggregate_failures do
    environment = create(:environment, project:)
    create(:variable, environment:, key: "BASE_URL", value: "https://api.example")
    create(:variable, environment:, key: "TOKEN", value: "hunter2hunter2", secret: true)
    create(:variable, environment:, key: "EMPTY", value: "")
    create(:variable, environment:, key: "OFF", enabled: false)
    membership.update!(current_environment: environment)
    get workbench_request_path(api_request)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("&quot;name&quot;:&quot;BASE_URL&quot;,&quot;set&quot;:true,&quot;value&quot;:&quot;https://api.example&quot;", "&quot;name&quot;:&quot;EMPTY&quot;,&quot;set&quot;:false")
    expect(response.body).to include("&quot;name&quot;:&quot;TOKEN&quot;,&quot;set&quot;:true,&quot;value&quot;:&quot;••••••&quot;")
    expect(response.body).not_to include("hunter2hunter2", "OFF")
  end

  it "renders inside a turbo frame layout" do
    get workbench_root_path, headers: { "Turbo-Frame" => "modal" }

    expect(response).to have_http_status(:ok)
  end
end
