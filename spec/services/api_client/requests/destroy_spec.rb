require "rails_helper"

RSpec.describe ApiClient::Requests::Destroy do
  let(:api_request) { create(:api_request) }

  it "destroys the request" do
    expect(described_class.call(api_request:)).to be_success
    expect(ApiRequest.exists?(api_request.id)).to be(false)
  end

  it "fails when destroy is halted" do
    allow(api_request).to receive(:destroy).and_return(false)

    expect(described_class.call(api_request:)).to be_failure
  end
end
