require "rails_helper"

RSpec.describe ApiClient::Folders::Destroy do
  let(:folder) { create(:folder) }

  it "destroys the folder" do
    result = described_class.call(folder:)

    expect(result).to be_success
    expect(Folder.exists?(folder.id)).to be(false)
  end

  it "fails when destroy is halted" do
    allow(folder).to receive(:destroy).and_return(false)

    expect(described_class.call(folder:)).to be_failure
  end
end
