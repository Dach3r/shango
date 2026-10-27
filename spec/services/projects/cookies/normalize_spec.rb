require "rails_helper"

RSpec.describe Projects::Cookies::Normalize do
  it "trims names, lowercases the domain without its leading dot and defaults the path", :aggregate_failures do
    attributes = described_class.call(attributes: { name: " sid ", domain: " .Example.COM ", path: "", expires_at: "", value: "x" })

    expect(attributes).to eq(name: "sid", domain: "example.com", path: "/", expires_at: nil, value: "x")
  end

  it "keeps a given path and expiry" do
    attributes = described_class.call(attributes: { path: "/v1", expires_at: "2037-10-21T07:28" })

    expect(attributes).to eq(path: "/v1", expires_at: "2037-10-21T07:28")
  end

  it "leaves out attributes that were not submitted" do
    expect(described_class.call(attributes: { value: "x" })).to eq(value: "x")
  end
end
