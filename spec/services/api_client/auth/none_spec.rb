require "rails_helper"

RSpec.describe ApiClient::Auth::None do
  it "leaves the request untouched" do
    request = ApiClient::Auth::Request.new(http_method: "GET", url: "https://a.test", headers: {}, body: nil)

    described_class.new({}).apply(request)

    expect(request.headers).to eq({})
  end
end
