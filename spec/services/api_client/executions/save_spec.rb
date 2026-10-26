require "rails_helper"

RSpec.describe ApiClient::Executions::Save do
  let(:api_request) { create(:api_request) }
  let(:user) { create(:user) }
  let(:pending) { build(:request_execution, id: SecureRandom.uuid, api_request:, user:).stash }
  let(:result) { described_class.call(api_request:, user:, id: pending.id) }

  before { allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new) }

  it "stores the pending execution and clears the cache", :aggregate_failures do
    expect(result).to be_success
    expect(result.record).to be_persisted
    expect(RequestExecution.pending(pending.id)).to be_nil
  end

  it "fails when the execution expired or never existed" do
    expect(described_class.call(api_request:, user:, id: SecureRandom.uuid)).to be_failure
  end

  it "fails for another user", :aggregate_failures do
    expect(described_class.call(api_request:, user: create(:user), id: pending.id)).to be_failure
    expect(RequestExecution.count).to eq(0)
  end

  it "fails for another request" do
    expect(described_class.call(api_request: create(:api_request), user:, id: pending.id)).to be_failure
  end

  it "keeps only the most recent executions" do
    create_list(:request_execution, RequestExecution::KEEP_PER_REQUEST + 2, api_request:)
    pending

    result

    expect(api_request.request_executions.count).to eq(RequestExecution::KEEP_PER_REQUEST)
  end

  it "keeps all executions below the limit" do
    pending

    expect { result }.to change(api_request.request_executions, :count).by(1)
  end
end
