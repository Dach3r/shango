require "rails_helper"

RSpec.describe ApiClient::Requests::Duplicate do
  let(:api_request) { create(:api_request, name: "List") }

  it "copies the request after the original", :aggregate_failures do
    copy = described_class.call(api_request:).record

    expect(copy).to be_persisted
    expect(copy).to have_attributes(name: I18n.t("workbench.requests.copy_name", name: "List"), url: api_request.url)
    expect(copy.position).to be > api_request.position
  end

  it "shares attachments and remaps body form references", :aggregate_failures do
    upload = Rack::Test::UploadedFile.new(StringIO.new("data"), "text/plain", original_filename: "a.txt")
    api_request.update!(body_type: "multipart", body_form: [{ "key" => "f", "upload_token" => "t" }, { "key" => "plain", "value" => "1" }])
    ApiClient::Requests::AttachUploads.call(api_request:, uploads: { "t" => upload }, binary_upload: Rack::Test::UploadedFile.new(StringIO.new("bin"), "application/octet-stream", original_filename: "b.bin"))
    api_request.save!

    copy = described_class.call(api_request: api_request.reload).record
    file_row = copy.body_form.first

    expect(copy.body_form.last).not_to have_key("attachment_id")
    expect(file_row["attachment_id"]).to eq(copy.body_files.first.id.to_s)
    expect(file_row["attachment_id"]).not_to eq(api_request.body_form.first["attachment_id"])
    expect(copy.binary_body).to be_attached
  end
end
