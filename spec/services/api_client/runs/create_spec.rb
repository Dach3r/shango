require "rails_helper"

RSpec.describe ApiClient::Runs::Create do
  include ActiveJob::TestHelper

  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:collection) { create(:collection, project:) }
  let(:environment) { create(:environment, project:) }
  let(:options) { {} }
  let(:result) { described_class.call(collection:, user:, environment:, options:) }

  before do
    create(:api_request, collection:, name: "one", http_method: "POST")
    create(:api_request, collection:, name: "two")
  end

  it "plans one pending item per request and queues the job", :aggregate_failures do
    expect { result }.to have_enqueued_job(RunCollectionJob)

    run = result.record
    expect(run).to be_queued
    expect(run).to have_attributes(project:, collection:, user:, environment:, total_count: 2, folder: nil)
    expect(run.items.map { |item| [item.request_name, item.http_method, item.position, item.status] }).to eq([["one", "POST", 0, "pending"], ["two", "GET", 1, "pending"]])
  end

  it "normalizes the options", :aggregate_failures do
    expect(described_class.call(collection:, user: create(:user), options: { stop_on_failure: "1", persist_variables: "0", delay_ms: "999999" }).record.options)
      .to eq("stop_on_failure" => true, "persist_variables" => false, "delay_ms" => CollectionRun::MAX_DELAY_MS)
    expect(described_class.call(collection:, user: create(:user), options: { delay_ms: "-5" }).record.options["delay_ms"]).to eq(0)
  end

  it "covers a folder only" do
    folder = create(:folder, collection:)
    create(:api_request, collection:, folder:, name: "inside")

    run = described_class.call(collection:, folder:, user:).record

    expect(run.items.map(&:request_name)).to eq(["inside"])
    expect(run.folder).to eq(folder)
  end

  it "refuses a second run while one is in progress", :aggregate_failures do
    create(:collection_run, :running, project:, user:)

    expect(result).to be_failure
    expect(result.error).to eq(:already_running)
    expect(described_class.call(collection:, user: create(:user)).error).to be_nil
  end

  it "does not count a run that has been stuck for hours" do
    stuck = create(:collection_run, :running, project:, user:)
    stuck.update_columns(updated_at: 2.hours.ago)

    expect(result).to be_success
  end

  it "refuses an empty scope and one that is too large", :aggregate_failures do
    expect(described_class.call(collection: create(:collection, project:), user:)).to have_attributes(error: :empty)

    stub_const("ENV", ENV.to_h.merge("SHANGO_RUN_MAX_REQUESTS" => "1"))
    failure = described_class.call(collection:, user:)
    expect(failure).to have_attributes(error: :too_many)
    expect(failure.data[:max]).to eq(1)
  end

  it "plans nothing when it refuses", :aggregate_failures do
    expect { described_class.call(collection: create(:collection, project:), user:) }.not_to change(CollectionRun, :count)
    expect(enqueued_jobs).to be_empty
  end
end
