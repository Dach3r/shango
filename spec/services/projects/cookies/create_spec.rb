require "rails_helper"

RSpec.describe Projects::Cookies::Create do
  let(:project) { create(:project) }
  let(:environment) { create(:environment, project:) }
  let(:attributes) { { name: "sid", value: "abc", domain: "API.example.com", path: "/", secure: "1" } }
  let(:result) { described_class.call(project:, environment:, attributes:) }

  it "creates the cookie in the jar of the environment", :aggregate_failures do
    expect(result).to be_success
    expect(result.record).to have_attributes(project:, environment:, name: "sid", value: "abc", domain: "api.example.com", secure: true, host_only: true)
  end

  it "returns the invalid cookie", :aggregate_failures do
    failed = described_class.call(project:, environment:, attributes: attributes.merge(name: ""))

    expect(failed).to be_failure
    expect(failed.record.errors[:name]).to be_present
    expect(Cookie.count).to eq(0)
  end

  it "keeps the jar within its cap" do
    stub_const("Cookie::MAX_PER_JAR", 1)
    create(:cookie, project:, environment:, updated_at: 1.day.ago)

    expect { result }.not_to change(Cookie, :count)
  end
end
