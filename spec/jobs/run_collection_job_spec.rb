require "rails_helper"

RSpec.describe RunCollectionJob do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:collection) { create(:collection, project:) }

  before do
    create(:membership, :owner, user:, project:)
    create(:api_request, collection:, url: "https://api.example.com/a")
    ActiveJob::Base.queue_adapter = :test
  end

  it "performs a queued run", :aggregate_failures do
    stub_request(:get, "https://api.example.com/a").to_return(status: 200)
    run = ApiClient::Runs::Create.call(collection:, user:).record

    described_class.perform_now(run.id)

    expect(run.reload).to be_completed
  end

  it "ignores a run that is gone or already started", :aggregate_failures do
    run = ApiClient::Runs::Create.call(collection:, user:).record
    run.start!

    expect(ApiClient::Runs::Perform).not_to receive(:call)
    described_class.perform_now(run.id)
    described_class.perform_now(SecureRandom.uuid)
  end

  it "queues on the executions queue, one run per user at a time", :aggregate_failures do
    run = ApiClient::Runs::Create.call(collection:, user:).record

    expect(described_class.new(run.id).queue_name).to eq("executions")
    expect(described_class.concurrency_limit).to eq(1)
    expect(described_class.new(run.id).concurrency_key).to eq("RunCollectionJob/#{user.id}")
  end
end
