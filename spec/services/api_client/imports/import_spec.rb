require "rails_helper"

RSpec.describe ApiClient::Imports::Import do
  let(:project) { create(:project) }
  let(:user) { create(:user) }

  def run(content, target: project)
    described_class.call(project: target, creator: user, content:)
  end

  def fixture(name)
    file_fixture("imports/#{name}").read
  end

  def failure_with(model)
    model.errors.add(:base, "boom")
    Result.failure(model)
  end

  describe "input validation" do
    it "rejects empty content" do
      expect(run("  ").error).to eq(I18n.t("workbench.imports.errors.empty"))
    end

    it "rejects oversized content" do
      stub_const("#{described_class}::MAX_BYTES", 5)
      expect(run("{\"a\": 1}").error).to eq(I18n.t("workbench.imports.errors.too_large", max: 0))
    end

    it "rejects content that is neither JSON nor YAML objects", :aggregate_failures do
      expect(run("foo: [").error).to eq(I18n.t("workbench.imports.errors.invalid_content"))
      expect(run("just text").error).to eq(I18n.t("workbench.imports.errors.invalid_content"))
      expect(run("[1, 2]").error).to eq(I18n.t("workbench.imports.errors.invalid_content"))
    end

    it "rejects YAML with aliases or custom classes", :aggregate_failures do
      expect(run("a: &x 1\nb: *x").error).to eq(I18n.t("workbench.imports.errors.invalid_content"))
      expect(run("a: !ruby/object:Object {}").error).to eq(I18n.t("workbench.imports.errors.invalid_content"))
    end

    it "rejects documents with too many nodes" do
      stub_const("ApiClient::Imports::Support::MAX_NODES", 2)
      expect(run(fixture("postman_environment.json")).error).to eq(I18n.t("workbench.imports.errors.too_complex"))
    end

    it "rejects unknown formats and importer failures", :aggregate_failures do
      expect(run("{\"foo\": 1}").error).to eq(I18n.t("workbench.imports.errors.unknown_format"))
      expect(run("{\"openapi\": \"3.0.0\", \"paths\": {}}").error).to eq(I18n.t("workbench.imports.errors.invalid_openapi"))
    end

    it "fails cleanly on valid JSON with the wrong shape", :aggregate_failures do
      wrong = [
        { info: { name: "C" }, auth: { type: "basic", basic: { a: 1 } }, item: [] },
        { openapi: "3.0.0", info: "x", paths: { "/a" => { get: {} } } },
        { name: "b", root: "x", items: [] }
      ]

      wrong.each { |data| expect(run(data.to_json).error).to eq(I18n.t("workbench.imports.errors.invalid_content")) }
    end

    it "rejects YAML nested deep enough to overflow the parser" do
      expect(run(("[" * 20_000) + ("]" * 20_000)).error).to eq(I18n.t("workbench.imports.errors.invalid_content"))
    end

    it "ignores a leading BOM and fails on empty objects", :aggregate_failures do
      expect(run("\uFEFF#{{ info: { name: "C" }, item: [] }.to_json}")).to be_success
      expect(run("{}").error).to eq(I18n.t("workbench.imports.errors.unknown_format"))
    end

    it "reports an empty result" do
      allow(ApiClient::Imports::Postman).to receive(:call).and_return(Result.success({ collections: [], environments: [], warnings: [] }))
      expect(run(fixture("postman_environment.json")).error).to eq(I18n.t("workbench.imports.errors.nothing_to_import"))
    end
  end

  describe "importing a Postman collection" do
    subject(:result) { run(fixture("postman_collection.json")) }

    it "creates collection, folders, requests and the variables environment", :aggregate_failures do
      expect { result }.to change { [project.collections.count, project.environments.count] }.from([0, 0]).to([1, 1])
      expect(result).to be_success
      expect(result.data).to include(collections: 1, folders: 1, requests: 15, environments: 1)
      collection = project.collections.first
      folder = collection.folders.first
      expect(folder).to have_attributes(name: "Pets", auth_type: "basic")
      expect(folder.api_requests.pluck(:name)).to eq(["List pets", "Create pet"])
      expect(collection.api_requests.where(folder_id: nil).count).to eq(13)
      expect(project.environments.first.variables.first).to have_attributes(key: "baseUrl", value: "https://api.example.com")
    end

    it "credits the importing user as creator", :aggregate_failures do
      result

      expect(project.collections.map(&:creator)).to eq([user])
      expect(project.environments.map(&:creator)).to eq([user])
    end

    it "returns the warnings once", :aggregate_failures do
      expect(result.data[:warnings]).to include(I18n.t("workbench.imports.warnings.auth_unsupported", type: "hawk"))
      expect(result.data[:warnings]).to eq(result.data[:warnings].uniq)
    end

    it "keeps imported credentials encrypted" do
      result
      folder = project.collections.first.folders.first
      expect(folder.auth_config).to include("password" => "p")
      expect(Folder.connection.select_value("SELECT auth_config FROM folders WHERE id = '#{folder.id}'")).not_to include("username")
    end

    it "renames collections and environments that already exist", :aggregate_failures do
      run(fixture("postman_collection.json"))
      second = run(fixture("postman_collection.json"))
      third = run(fixture("postman_collection.json"))
      expect(second).to be_success
      expect(third).to be_success
      expect(project.collections.order(:created_at).pluck(:name)).to eq(["Pets", "Pets (2)", "Pets (3)"])
      expect(project.environments.pluck(:name)).to contain_exactly("Pets variables", "Pets variables (2)", "Pets variables (3)")
    end

    it "never touches other projects" do
      other = create(:project)
      result
      expect(other.collections.count + other.environments.count).to eq(0)
    end
  end

  describe "importing scripts and assertions" do
    let(:automation) { { "pre_request_script" => "// pre", "post_response_script" => "// post", "assertions" => [{ "source" => "status", "operator" => "equals", "expected" => "200" }], "extractors" => [{ "source" => "status", "variable" => "code" }] } }
    let(:document) do
      {
        shango: { version: 1 },
        collection: { name: "Scripted", auth_type: "none", **automation, folders: [{ name: "F", **automation, folders: [], requests: [] }], requests: [{ name: "R", url: "https://a.test", body_type: "none", **automation }] }
      }
    end

    it "gives them to the collection, the folders and the requests", :aggregate_failures do
      expect(run(document.to_json)).to be_success

      collection = project.collections.find_by(name: "Scripted")
      [collection, collection.folders.first, collection.api_requests.first].each do |record|
        expect(record).to have_attributes(pre_request_script: "// pre", post_response_script: "// post")
        expect(record.assertions).to contain_exactly(include("source" => "status", "operator" => "equals"))
        expect(record.extractors).to contain_exactly(include("variable" => "code"))
      end
    end

    it "keeps the scripts of a Postman collection at every level", :aggregate_failures do
      event = ->(listen, code) { [{ "listen" => listen, "script" => { "exec" => [code] } }] }
      data = {
        info: { name: "Postman scripted" }, event: event.("prerequest", "// collection"),
        item: [{ name: "Folder", event: event.("test", "// folder"), item: [{ name: "Req", event: event.("test", "pm.test('x', () => {});"), request: { url: "http://x" } }] }]
      }
      result = run(data.to_json)

      collection = project.collections.find_by(name: "Postman scripted")
      expect(result).to be_success
      expect(collection.pre_request_script).to eq("// collection")
      expect(collection.folders.first.post_response_script).to eq("// folder")
      expect(collection.api_requests.first.post_response_script).to eq("pm.test('x', () => {});")
    end

    it "leaves a collection without any alone" do
      run({ shango: { version: 1 }, collection: { name: "Plain", auth_type: "none", folders: [], requests: [] } }.to_json)

      expect(project.collections.find_by(name: "Plain")).to have_attributes(pre_request_script: nil, assertions: [])
    end
  end

  describe "importing environments" do
    it "skips invalid names and keeps the last of duplicated keys", :aggregate_failures do
      content = { name: "E", values: [{ key: "a", value: "1" }, { key: "bad key", value: "x" }, { key: "a", value: "2" }, { key: "tok", value: "s", type: "secret" }] }.to_json
      result = run("﻿#{content}")
      variables = project.environments.first.variables
      expect(result.data[:warnings]).to eq([I18n.t("workbench.imports.warnings.variable_skipped", key: "bad key")])
      expect(variables.pluck(:key, :value, :secret)).to contain_exactly(["a", "2", false], ["tok", "s", true])
    end
  end

  describe "other formats" do
    it "reads YAML (Insomnia v5)", :aggregate_failures do
      result = run(fixture("insomnia_v5.yaml"))
      expect(result).to be_success
      expect(result.data).to include(collections: 1, folders: 2, requests: 2, environments: 1)
    end

    it "imports Insomnia v4, Bruno, OpenAPI and Swagger", :aggregate_failures do
      %w[insomnia_v4.json bruno_collection.json openapi3.json swagger2.json].each do |file|
        expect(run(fixture(file))).to be_success
      end
      expect(project.collections.pluck(:name)).to contain_exactly("Shop", "Bruno Demo", "Petstore", "Legacy")
    end
  end

  describe "rollback" do
    {
      "a collection" => [ApiClient::Collections::Create, -> { Collection.new }],
      "a folder" => [ApiClient::Folders::Create, -> { Folder.new }],
      "a request" => [ApiClient::Requests::Create, -> { ApiRequest.new }],
      "an environment" => [Projects::Environments::Create, -> { Environment.new }]
    }.each do |label, (service, model)|
      it "undoes everything when #{label} cannot be created", :aggregate_failures do
        allow(service).to receive(:call).and_return(failure_with(model.call))
        result = run(fixture("postman_collection.json"))
        expect(result.error).to eq(I18n.t("workbench.imports.errors.failed", message: "boom"))
        expect(project.collections.count + project.environments.count).to eq(0)
      end
    end
  end
end
