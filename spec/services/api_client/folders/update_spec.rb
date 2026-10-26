require "rails_helper"

RSpec.describe ApiClient::Folders::Update do
  let(:folder) { create(:folder, name: "Old") }

  it "updates the name and auth", :aggregate_failures do
    result = described_class.call(folder:, attributes: { name: "New", auth_type: "bearer", auth_config: { "token" => "abc" } })

    expect(result).to be_success
    expect(folder.reload).to have_attributes(name: "New", auth_type: "bearer")
  end

  it "fails when the folder is invalid" do
    expect(described_class.call(folder:, attributes: { name: "" })).to be_failure
  end
end
