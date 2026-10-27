require "rails_helper"

RSpec.describe Projects::Cookies::Update do
  let(:cookie) { create(:cookie, name: "sid", value: "old") }

  it "updates the cookie", :aggregate_failures do
    result = described_class.call(cookie:, attributes: { value: "new", path: "/v1", http_only: "1" })

    expect(result).to be_success
    expect(cookie.reload).to have_attributes(value: "new", path: "/v1", http_only: true)
  end

  it "returns the invalid cookie", :aggregate_failures do
    result = described_class.call(cookie:, attributes: { name: "" })

    expect(result).to be_failure
    expect(cookie.reload.name).to eq("sid")
  end
end
