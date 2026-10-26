require "rails_helper"

RSpec.describe ApiClient::Oauth2::FindOwner do
  let(:project) { create(:project) }
  let(:collection) { create(:collection, project:, auth_type: "oauth2") }

  it "finds an owner of each supported type", :aggregate_failures do
    folder = create(:folder, collection:, auth_type: "oauth2")
    api_request = create(:api_request, collection:, auth_type: "oauth2")

    expect(described_class.call(project:, type: "Collection", id: collection.id)).to eq(collection)
    expect(described_class.call(project:, type: "Folder", id: folder.id)).to eq(folder)
    expect(described_class.call(project:, type: "ApiRequest", id: api_request.id)).to eq(api_request)
  end

  it "raises for unsupported types" do
    expect { described_class.call(project:, type: "User", id: collection.id) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "raises when the owner belongs to another project" do
    expect { described_class.call(project: create(:project), type: "Collection", id: collection.id) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "raises when the owner does not use oauth2" do
    plain = create(:collection, project:)

    expect { described_class.call(project:, type: "Collection", id: plain.id) }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
