RSpec.describe RequestFormHelper do
  describe "#url_parts" do
    it "splits scheme, host, path, query and fragment" do
      expect(helper.url_parts("https://a.io/x/y?q=1#top")).to eq(scheme: "https://", host: "a.io", path: "/x/y", query: "?q=1", fragment: "#top")
    end

    it "keeps schemeless and templated URLs readable" do
      expect(helper.url_parts("{{base}}/users")).to include(scheme: nil, host: "{{base}}", path: "/users")
    end
  end

  describe "#param_rows" do
    it "returns saved rows" do
      request = build(:api_request, query_params: [{ "key" => "a", "value" => "1" }])
      request.valid?

      expect(helper.param_rows(request)).to eq(request.query_params)
    end

    it "parses the URL query string when none saved", :aggregate_failures do
      request = build(:api_request, url: "https://x.test/p?a=1&b=hello%20w&flag&&#frag")

      expect(helper.param_rows(request)).to contain_exactly(
        { "key" => "a", "value" => "1", "enabled" => true, "description" => "" },
        { "key" => "b", "value" => "hello w", "enabled" => true, "description" => "" },
        { "key" => "flag", "value" => "", "enabled" => true, "description" => "" }
      )
    end

    it "returns nothing without a query string" do
      expect(helper.param_rows(build(:api_request, url: "https://x.test/p"))).to be_empty
    end
  end

  describe "#body_type_options" do
    it "pairs translated labels with types", :aggregate_failures do
      options = helper.body_type_options

      expect(options.map(&:last)).to eq(ApiRequest::BODY_TYPES)
      expect(options.map(&:first)).to all(be_a(String))
    end
  end

  describe "#method_options" do
    it "pairs each method with itself" do
      expect(helper.method_options).to eq(ApiRequest::METHODS.map { |m| [m, m] })
    end
  end

  describe "#request_breadcrumb" do
    let(:project) { create(:project) }
    let(:collection) { create(:collection, project:, name: "Docs") }
    let(:parent) { create(:folder, collection:, name: "Users") }
    let(:folder) { create(:folder, collection:, parent:, name: "Admin") }
    let(:branches) { ApiClient::Tree::Load.call(project:) }

    it "lists the collection and every folder down to the request", :aggregate_failures do
      expect(helper.request_breadcrumb(create(:api_request, collection:, folder:), branches)).to eq(%w[Docs Users Admin])
      expect(helper.request_breadcrumb(create(:api_request, collection:), branches)).to eq(%w[Docs])
    end

    it "names drafts" do
      draft = create(:api_request, project:, collection: nil, user: create(:user))

      expect(helper.request_breadcrumb(draft, branches)).to eq([I18n.t("workbench.requests.draft")])
    end
  end

  describe "#variable_autocomplete_data" do
    before do
      helper.define_singleton_method(:editor_variables) { [{ name: "token", set: true, value: "abc" }] }
      helper.define_singleton_method(:editor_responses) { [{ id: "1", name: "Login" }] }
      helper.define_singleton_method(:editor_responses_url) { "/workbench/requests/1/response_reference" }
    end

    it "exposes the variables and labels to the controller", :aggregate_failures do
      data = helper.variable_autocomplete_data(controller: "request-url")

      expect(data[:controller]).to eq("request-url variable-autocomplete")
      expect(JSON.parse(data[:variable_autocomplete_variables_value])).to eq([{ "name" => "token", "set" => true, "value" => "abc" }])
      expect(JSON.parse(data[:variable_autocomplete_responses_value])).to eq([{ "id" => "1", "name" => "Login" }])
      expect(data[:variable_autocomplete_responses_url_value]).to eq("/workbench/requests/1/response_reference")
      expect(JSON.parse(data[:variable_autocomplete_labels_value])).to include("environment" => "Environment", "isoTimestamp" => "ISO 8601 date")
    end

    it "defaults to the autocomplete controller alone" do
      expect(helper.variable_autocomplete_data[:controller]).to eq("variable-autocomplete")
    end
  end
end
