require "rails_helper"

RSpec.describe ApiClient::Requests::Create do
  let(:collection) { create(:collection) }
  let(:folder) { create(:folder, collection:) }

  it "creates a request with inherited auth by default", :aggregate_failures do
    result = described_class.call(collection:, attributes: { name: "List", url: "https://x.test", folder_id: folder.id, bogus: 1 })

    expect(result).to be_success
    expect(result.record).to have_attributes(collection:, folder:, name: "List", auth_type: "inherit", project: collection.project)
  end

  it "stores the given auth" do
    result = described_class.call(collection:, attributes: { name: "List", auth_type: "bearer", auth_config: { "token" => "abc" } })

    expect(result.record).to have_attributes(auth_type: "bearer", auth_config: include("token" => "abc"))
  end

  it "attaches uploaded files", :aggregate_failures do
    upload = Rack::Test::UploadedFile.new(StringIO.new("data"), "text/plain", original_filename: "a.txt")

    result = described_class.call(collection:, attributes: { name: "List" }, binary_upload: upload)

    expect(result).to be_success
    expect(result.record.binary_body).to be_attached
  end

  it "fails when the request is invalid" do
    result = described_class.call(collection:, attributes: { name: "" })

    expect(result).to be_failure
    expect(result.record).not_to be_persisted
  end
end
