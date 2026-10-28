require "rails_helper"

RSpec.describe ApiClient::Exports::Enqueue do
  let(:collection) { create(:collection) }
  let(:user) { create(:user) }

  it "records the request and queues the job", :aggregate_failures do
    result = nil

    expect { result = described_class.call(collection:, user:, format: "openapi", include_environments: true) }.to have_enqueued_job(ExportCollectionJob)
    expect(result.record).to have_attributes(project: collection.project, user:, collection:, export_format: "openapi", include_environments: true, include_credentials: false, status: "queued")
    expect(result.record.expires_at).to be > 30.minutes.from_now
  end

  it "rejects an unknown format without queueing", :aggregate_failures do
    result = nil

    expect { result = described_class.call(collection:, user:, format: "csv") }.not_to have_enqueued_job
    expect(result).to be_failure
    expect(result.error).to eq(I18n.t("workbench.exports.errors.unknown_format"))
  end
end
