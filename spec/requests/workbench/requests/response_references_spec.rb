require "rails_helper"

RSpec.describe "Workbench request response references" do
  include_context "with workbench project"

  let(:source) { create(:api_request, collection:) }

  def preview(name, request: api_request)
    get workbench_request_response_reference_path(request, name:)
    response.parsed_body
  end

  before { allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new) }

  it "previews the value of a reference", :aggregate_failures do
    create(:request_execution, api_request: source, user:, response_body: '{"id":638}')

    expect(preview("response.body.#{source.id}.$.id")).to eq("status" => "ok", "value" => "638")
  end

  it "truncates long values" do
    create(:request_execution, api_request: source, user:, response_body: "x" * 800)

    expect(preview("response.raw.#{source.id}")["value"].length).to eq(500)
  end

  it "reports why a reference does not resolve", :aggregate_failures do
    expect(preview("response.url.#{source.id}")).to eq("status" => "no_response")
    expect(preview("response.url.#{foreign_request.id}")).to eq("status" => "unknown_request")
    expect(preview("nope")).to eq("status" => "invalid")
  end

  it "does not reach requests of other projects" do
    get workbench_request_response_reference_path(foreign_request, name: "response.url.#{source.id}")

    expect(response).to have_http_status(:not_found)
  end

  describe "editor data" do
    it "offers the other requests of the collection only", :aggregate_failures do
      sibling = create(:api_request, collection:, folder:, name: "Create travel", http_method: "POST")
      foreign_request

      get workbench_request_path(api_request)
      responses = Nokogiri::HTML(response.body).css("[data-code-editor-responses-value]").map { |node| JSON.parse(node["data-code-editor-responses-value"]) }.flatten.uniq

      expect(responses).to eq([{ "id" => sibling.id, "name" => "Create travel", "method" => "POST", "folder" => folder.name }])
    end

    it "is empty for a draft", :aggregate_failures do
      draft = create(:api_request, collection: nil, user:, project:)

      get workbench_request_path(draft)

      expect(response.body).to include("data-code-editor-responses-value=\"[]\"")
      expect(response.body).not_to include("responses-url-value")
    end
  end
end
