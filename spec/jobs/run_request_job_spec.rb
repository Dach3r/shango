require "rails_helper"

RSpec.describe RunRequestJob do
  let(:state) { ApiClient::Executions::RunState }
  let(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:collection) { create(:collection, project:) }
  let(:api_request) { create(:api_request, collection:, url: "https://api.example.com/items") }
  let(:environment) { create(:environment, project:) }
  let(:run_id) { SecureRandom.uuid }

  before do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    state.start(run_id, user_id: user.id, api_request_id: api_request.id)
  end

  it "runs on the executions queue" do
    expect(described_class.new.queue_name).to eq("executions")
  end

  it "sends the request, stashes the response and marks the run done", :aggregate_failures do
    stub_request(:get, api_request.url).to_return(status: 200, body: "hello", headers: { "Content-Type" => "text/plain" })

    described_class.perform_now(user.id, api_request.id, environment.id, run_id)

    expect(state.read(run_id)).to include("state" => "done")
    expect(RequestExecution.pending(run_id)).to have_attributes(response_body: "hello", user:, environment:)
  end

  it "works without an environment" do
    stub_request(:get, api_request.url).to_return(status: 200)

    described_class.perform_now(user.id, api_request.id, nil, run_id)

    expect(RequestExecution.pending(run_id)).to have_attributes(environment: nil, status: 200)
  end

  it "skips runs cancelled while queued", :aggregate_failures do
    state.cancel(run_id)

    described_class.perform_now(user.id, api_request.id, nil, run_id)

    expect(state.read(run_id)).to include("state" => "cancelled")
    expect(a_request(:get, api_request.url)).not_to have_been_made
  end

  it "marks runs cancelled while in flight", :aggregate_failures do
    stub_request(:get, api_request.url).to_return { state.cancel(run_id) and { status: 200, body: "late" } }

    described_class.perform_now(user.id, api_request.id, nil, run_id)

    expect(state.read(run_id)).to include("state" => "cancelled")
    expect(RequestExecution.pending(run_id)).to have_attributes(error_kind: "cancelled")
  end

  it "marks the run failed instead of raising when something unexpected breaks", :aggregate_failures do
    allow(ApiClient::Requests::Dispatch).to receive(:call).and_raise(StandardError, "boom")

    expect { described_class.perform_now(user.id, api_request.id, nil, run_id) }.not_to raise_error
    expect(state.read(run_id)).to include("state" => "failed")
  end

  it "marks the run failed when the user no longer exists", :aggregate_failures do
    described_class.perform_now(SecureRandom.uuid, api_request.id, nil, run_id)

    expect(state.read(run_id)).to include("state" => "failed")
    expect(RequestExecution.pending(run_id)).to be_nil
  end

  it "marks the run failed when the request was deleted meanwhile", :aggregate_failures do
    id = api_request.id
    api_request.destroy
    described_class.perform_now(user.id, id, nil, run_id)

    expect(state.read(run_id)).to include("state" => "failed")
  end

  it "runs without an environment when it was deleted meanwhile" do
    stub_request(:get, api_request.url).to_return(status: 200)
    id = environment.id
    environment.destroy
    described_class.perform_now(user.id, api_request.id, id, run_id)

    expect(state.read(run_id)).to include("state" => "done")
  end

  it "does not log the request body or secrets when it fails", :aggregate_failures do
    allow(Rails.logger).to receive(:error)
    allow(ApiClient::Requests::Dispatch).to receive(:call).and_raise(StandardError, "boom")
    described_class.perform_now(user.id, api_request.id, nil, run_id)

    expect(Rails.logger).to have_received(:error).with("RunRequestJob #{run_id} failed: StandardError: boom")
  end
end
