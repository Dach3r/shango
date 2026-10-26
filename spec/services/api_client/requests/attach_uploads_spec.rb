require "rails_helper"

RSpec.describe ApiClient::Requests::AttachUploads do
  let(:api_request) { create(:api_request, body_type: "multipart", body_form: [{ "key" => "f", "upload_token" => "t1" }]) }

  def upload(name)
    Rack::Test::UploadedFile.new(StringIO.new("data"), "text/plain", original_filename: name)
  end

  it "attaches files to their form rows", :aggregate_failures do
    described_class.call(api_request:, uploads: { "t1" => upload("a.txt"), "unknown" => upload("b.txt") })
    api_request.save!
    row = api_request.reload.body_form.first

    expect(row).to include("type" => "file", "value" => "a.txt", "attachment_id" => api_request.body_files.first.id.to_s)
    expect(row).not_to have_key("upload_token")
    expect(api_request.body_files.count).to eq(1)
  end

  it "ignores blank uploads" do
    described_class.call(api_request:, uploads: { "t1" => nil })

    expect(api_request.body_files.count).to eq(0)
  end

  it "replaces the binary body" do
    described_class.call(api_request:, binary_upload: upload("old.bin"))
    described_class.call(api_request: api_request.reload, binary_upload: upload("new.bin"))

    expect(api_request.reload.binary_body.filename.to_s).to eq("new.bin")
  end

  it "purges files that are no longer referenced" do
    described_class.call(api_request:, uploads: { "t1" => upload("a.txt") })
    api_request.save!
    api_request.update!(body_form: [])

    expect { described_class.call(api_request: api_request.reload) }.to have_enqueued_job(ActiveStorage::PurgeJob)
  end

  it "keeps referenced files" do
    described_class.call(api_request:, uploads: { "t1" => upload("a.txt") })
    api_request.save!

    expect { described_class.call(api_request: api_request.reload) }.not_to have_enqueued_job(ActiveStorage::PurgeJob)
  end
end
