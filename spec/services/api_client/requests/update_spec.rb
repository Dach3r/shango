require "rails_helper"

RSpec.describe ApiClient::Requests::Update do
  let(:api_request) { create(:api_request, name: "Old") }

  it "updates the permitted attributes", :aggregate_failures do
    result = described_class.call(api_request:, attributes: { name: "New", http_method: "POST", auth_type: "bearer", auth_config: { "token" => "abc" }, project_id: "x" })

    expect(result).to be_success
    expect(api_request.reload).to have_attributes(name: "New", http_method: "POST", auth_type: "bearer", project: api_request.collection.project)
  end

  describe "upload limits" do
    def upload(name, bytes = 10)
      Rack::Test::UploadedFile.new(StringIO.new("x" * bytes), "text/plain", original_filename: name)
    end

    let(:api_request) { create(:api_request, body_type: "multipart", body_form: [{ "key" => "f", "upload_token" => "t1" }, { "key" => "g", "upload_token" => "t2" }]) }

    def limited(**env)
      stub_const("ENV", ENV.to_h.merge(env.transform_keys(&:to_s)))
    end

    it "accepts files within the limits", :aggregate_failures do
      result = described_class.call(api_request:, attributes: {}, uploads: { "t1" => upload("a.txt") })

      expect(result).to be_success
      expect(api_request.body_files.count).to eq(1)
    end

    it "rejects a file over the per-file limit", :aggregate_failures do
      limited(SHANGO_MAX_UPLOAD_MB: "1")
      result = described_class.call(api_request:, attributes: {}, uploads: { "t1" => upload("big.bin", 2.megabytes) })

      expect(result).to be_failure
      expect(api_request.errors.full_messages.to_sentence).to eq("big.bin is larger than the 1 MB limit.")
      expect(api_request.body_files.count).to eq(0)
    end

    it "rejects a binary body over the per-file limit" do
      limited(SHANGO_MAX_UPLOAD_MB: "1")

      expect(described_class.call(api_request:, attributes: {}, binary_upload: upload("big.bin", 2.megabytes))).to be_failure
    end

    it "rejects submissions over the total limit", :aggregate_failures do
      limited(SHANGO_MAX_UPLOADS_TOTAL_MB: "1")
      result = described_class.call(api_request:, attributes: {}, uploads: { "t1" => upload("a.bin", 700.kilobytes), "t2" => upload("b.bin", 700.kilobytes) })

      expect(result).to be_failure
      expect(api_request.errors.full_messages.to_sentence).to eq("Files together are larger than the 1 MB limit.")
    end

    it "rejects submissions with too many files", :aggregate_failures do
      limited(SHANGO_MAX_UPLOADS: "1")
      result = described_class.call(api_request:, attributes: {}, uploads: { "t1" => upload("a.txt"), "t2" => upload("b.txt") })

      expect(result).to be_failure
      expect(api_request.errors.full_messages.to_sentence).to eq("Too many files in one request (maximum 1).")
    end

    it "ignores invalid limit overrides" do
      limited(SHANGO_MAX_UPLOAD_MB: "-3")

      expect(described_class.call(api_request:, attributes: {}, uploads: { "t1" => upload("a.txt") })).to be_success
    end
  end

  it "fails when the request is invalid" do
    expect(described_class.call(api_request:, attributes: { name: "" })).to be_failure
  end
end
