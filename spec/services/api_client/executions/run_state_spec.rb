require "rails_helper"

RSpec.describe ApiClient::Executions::RunState do
  let(:id) { SecureRandom.uuid }
  let(:user_id) { SecureRandom.uuid }
  let(:api_request_id) { SecureRandom.uuid }

  before { allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new) }

  it "starts as running and keeps who owns it", :aggregate_failures do
    described_class.start(id, user_id:, api_request_id:, uploaded: true)

    expect(described_class.read(id)).to eq("state" => "running", "user_id" => user_id, "api_request_id" => api_request_id, "uploaded" => true)
  end

  it "only hands the state to its user and request", :aggregate_failures do
    described_class.start(id, user_id:, api_request_id:)

    expect(described_class.for(id, user_id:, api_request_id:)).to include("state" => "running")
    expect(described_class.for(id, user_id: SecureRandom.uuid, api_request_id:)).to be_nil
    expect(described_class.for(id, user_id:, api_request_id: SecureRandom.uuid)).to be_nil
    expect(described_class.for(SecureRandom.uuid, user_id:, api_request_id:)).to be_nil
  end

  it "finishes with a new state" do
    described_class.start(id, user_id:, api_request_id:)
    described_class.finish(id, "done")

    expect(described_class.read(id)).to include("state" => "done")
  end

  it "ignores finishing an unknown run" do
    described_class.finish(id, "done")

    expect(described_class.read(id)).to be_nil
  end

  it "records cancellation", :aggregate_failures do
    expect(described_class.cancelled?(id)).to be(false)
    described_class.cancel(id)

    expect(described_class.cancelled?(id)).to be(true)
  end
end
