require "rails_helper"

RSpec.describe ApiClient::Requests::Stash do
  let(:api_request) { create(:api_request) }
  let(:user) { create(:user) }
  let(:attributes) { { name: "Edited", url: "https://edited.test", headers: [{ key: "X", value: "1" }] } }

  before { allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new) }

  it "keeps the attributes per user and request", :aggregate_failures do
    described_class.write(api_request:, user:, attributes:)

    expect(described_class.read(api_request:, user:)).to include("name" => "Edited", "headers" => [{ "key" => "X", "value" => "1" }])
    expect(described_class.read(api_request:, user: create(:user))).to be_nil
    expect(described_class.read(api_request: create(:api_request), user:)).to be_nil
  end

  it "does not store the payload in plain text" do
    described_class.write(api_request:, user:, attributes:)

    expect(Rails.cache.read("api_client/request_stash/#{user.id}/#{api_request.id}")).not_to include("edited.test")
  end

  it "drops secret auth fields and keeps the rest", :aggregate_failures do
    described_class.write(api_request:, user:, attributes: { auth_type: "basic", auth_config: { "username" => "ana", "password" => "s3cret" } })

    expect(described_class.read(api_request:, user:)["auth_config"]).to eq("username" => "ana")
  end

  it "keeps auth config as is for an auth type without strategy" do
    described_class.write(api_request:, user:, attributes: { auth_type: "inherit" })

    expect(described_class.read(api_request:, user:)["auth_config"]).to eq({})
  end

  it "refuses a state over the size limit", :aggregate_failures do
    stub_const("#{described_class}::MAX_BYTES", 10)

    expect(described_class.write(api_request:, user:, attributes:)).to be(false)
    expect(described_class.read(api_request:, user:)).to be_nil
  end

  it "ignores a payload it cannot decrypt" do
    Rails.cache.write("api_client/request_stash/#{user.id}/#{api_request.id}", "garbage")

    expect(described_class.read(api_request:, user:)).to be_nil
  end

  it "clears the state" do
    described_class.write(api_request:, user:, attributes:)
    described_class.clear(api_request:, user:)

    expect(described_class.read(api_request:, user:)).to be_nil
  end

  it "lists the requests with unsaved state" do
    other = create(:api_request)
    described_class.write(api_request:, user:, attributes:)

    expect(described_class.ids(requests: [api_request, other], user:)).to eq([api_request.id])
  end
end
