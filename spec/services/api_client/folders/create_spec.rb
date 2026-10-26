require "rails_helper"

RSpec.describe ApiClient::Folders::Create do
  let(:collection) { create(:collection) }
  let(:parent) { create(:folder, collection:) }

  it "creates a root folder inheriting auth by default" do
    result = described_class.call(collection:, attributes: { name: "Users" })

    expect(result).to be_success
    expect(result.record).to have_attributes(name: "Users", parent_id: nil, auth_type: "inherit")
  end

  it "creates a nested folder with its own auth" do
    result = described_class.call(
      collection:,
      attributes: { name: "Users", parent_id: parent.id, auth_type: "bearer", auth_config: { "token" => "abc" } }
    )

    expect(result.record).to have_attributes(parent:, auth_type: "bearer")
  end

  it "fails when the folder is invalid" do
    expect(described_class.call(collection:, attributes: { name: "" })).to be_failure
  end
end
