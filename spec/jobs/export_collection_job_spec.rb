require "rails_helper"

RSpec.describe ExportCollectionJob do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:collection) { create(:collection, project:, name: "Pets") }
  let(:export) { create(:collection_export, project:, user:, collection:, export_format: "postman") }

  before do
    folder = create(:folder, collection:)
    create(:api_request, collection:, folder:, name: "One")
    create(:api_request, collection:, name: "Two")
  end

  it "runs on the exports queue" do
    expect(described_class.new.queue_name).to eq("exports")
  end

  it "builds the file, stores it encrypted and reports the progress", :aggregate_failures do
    steps = []
    allow_any_instance_of(CollectionExport).to receive(:update_columns).and_wrap_original do |original, **attributes| # rubocop:disable RSpec/AnyInstance
      steps << attributes[:progress] if attributes[:progress]
      original.call(**attributes)
    end

    described_class.perform_now(user.id, export.id)

    expect(export.reload).to be_done
    expect(export).to have_attributes(progress: 100, filename: "pets.postman_collection.json", content_type: "application/json")
    expect(JSON.parse(export.file_content).dig("info", "name")).to eq("Pets")
    expect(steps).to eq(steps.sort).and include(45, 90, 95)
  end

  it "keeps the credentials and environments the member asked for", :aggregate_failures do
    create(:environment, project:, name: "Prod")
    collection.update!(auth_type: "basic", auth_config: { "username" => "u", "password" => "pw-1" })
    export.update!(export_format: "shango", include_environments: true, include_credentials: true)

    described_class.perform_now(user.id, export.id)

    expect(export.reload.file_content).to include("pw-1").and include("Prod")
  end

  it "keeps the expiry from the moment it finished" do
    export.update!(expires_at: 1.minute.from_now)

    described_class.perform_now(user.id, export.id)

    expect(export.reload.expires_at).to be > 30.minutes.from_now
  end

  it "ignores exports that are gone or already taken", :aggregate_failures do
    expect { described_class.perform_now(user.id, SecureRandom.uuid) }.not_to raise_error
    export.update!(status: "running")
    described_class.perform_now(user.id, export.id)

    expect(export.reload).to be_running
  end

  it "marks the export failed without leaking the error", :aggregate_failures do
    allow(ApiClient::Exports::Export).to receive(:call).and_raise(StandardError, "boom")
    allow(Rails.logger).to receive(:error)

    described_class.perform_now(user.id, export.id)

    expect(export.reload).to have_attributes(status: "failed", error: "unexpected")
    expect(Rails.logger).to have_received(:error).with("ExportCollectionJob #{export.id} failed (user #{user.id}): StandardError: boom")
  end
end
