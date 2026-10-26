require "rails_helper"

RSpec.describe ApiClient::Requests::ImportCurl do
  let(:collection) { create(:collection) }

  it "creates a request from a curl command", :aggregate_failures do
    result = described_class.call(collection:, command: "curl -X POST https://x.test/a -d 'k=v'")

    expect(result).to be_success
    expect(result.record).to have_attributes(http_method: "POST", url: "https://x.test/a", folder_id: nil)
  end

  it "places the request in a folder" do
    folder = create(:folder, collection:)

    result = described_class.call(collection:, command: "curl https://x.test", folder_id: folder.id)

    expect(result.record.folder).to eq(folder)
  end

  it "returns the parser error" do
    result = described_class.call(collection:, command: "")

    expect(result).to be_failure
    expect(result.error).to eq(I18n.t("workbench.curl.empty"))
  end
end
