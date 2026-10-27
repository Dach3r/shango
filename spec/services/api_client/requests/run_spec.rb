require "rails_helper"

RSpec.describe ApiClient::Requests::Run do
  let(:project) { create(:project) }
  let(:collection) { create(:collection, project:) }
  let(:api_request) { create(:api_request, collection:, url: "https://api.example.com/items") }
  let(:user) { create(:user) }
  let(:environment) { create(:environment, project:) }
  let(:attributes) { {} }
  let(:result) { described_class.call(api_request:, environment:, user:, attributes:) }
  let(:execution) { result.record }

  before { allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new) }

  it "builds the execution without storing it", :aggregate_failures do
    stub_request(:get, api_request.url).to_return(status: 200, body: "hello", headers: { "Content-Type" => "text/plain" })

    expect(result).to be_success
    expect(execution).to be_new_record
    expect(RequestExecution.pending(execution.id)).to have_attributes(response_body: "hello", url: api_request.url)
    expect(execution).to have_attributes(
      http_method: "GET", url: api_request.url, status: 200, status_text: "OK", response_body: "hello", content_type: "text/plain", size_bytes: 5,
      body_omitted: false, body_truncated: false, error_kind: nil, user:, environment:, project:, api_request:, redirects: []
    )
  end

  describe "in async mode" do
    include ActiveJob::TestHelper

    before { stub_const("ENV", ENV.to_h.merge("SHANGO_EXECUTION_MODE" => "async")) }

    it "queues the send and returns the run id", :aggregate_failures do
      run_id = nil

      expect { run_id = result.data[:run_id] }.to have_enqueued_job(RunRequestJob).with(user.id, api_request.id, environment.id, a_kind_of(String))
      expect(result).to be_success
      expect(result.record).to be_nil
      expect(ApiClient::Executions::RunState.read(run_id)).to include("state" => "running", "user_id" => user.id, "uploaded" => false)
      expect(a_request(:get, api_request.url)).not_to have_been_made
    end

    it "flags uploads so the page refreshes with the result", :aggregate_failures do
      upload = Rack::Test::UploadedFile.new(StringIO.new("data"), "text/plain", original_filename: "a.txt")
      api_request.update!(body_type: "binary")
      queued = described_class.call(api_request:, environment:, user:, attributes: { body_type: "binary" }, binary_upload: upload)

      expect(ApiClient::Executions::RunState.read(queued.data[:run_id])).to include("uploaded" => true)
    end

    it "queues without an environment" do
      expect { described_class.call(api_request:, environment: nil, user:) }.to have_enqueued_job(RunRequestJob).with(user.id, api_request.id, nil, a_kind_of(String))
    end

    it "still reports invalid edits right away", :aggregate_failures do
      queued = described_class.call(api_request:, environment:, user:, attributes: { name: "" })

      expect(queued).to be_failure
      expect(RunRequestJob).not_to have_been_enqueued
    end
  end

  it "lets a later request in the collection use the unsaved response", :aggregate_failures do
    stub_request(:get, api_request.url).to_return(status: 200, body: '{"id":638}', headers: { "Content-Type" => "application/json" })
    described_class.call(api_request:, environment:, user:)
    follower = create(:api_request, collection:, url: "https://api.example.com/items/{{response.body.#{api_request.id}.$.id}}")
    stub_request(:get, "https://api.example.com/items/638").to_return(status: 200, body: "found")

    run = described_class.call(api_request: follower, environment:, user:)

    expect(run.record).to have_attributes(url: "https://api.example.com/items/638", response_body: "found")
  end

  it "stores the response timings" do
    stub_request(:get, "https://api.example.com/items").to_return(status: 200, body: "ok")

    expect(result.record.timings.keys).to include("ttfb", "download")
  end

  it "stores each cookie the response sets, masked", :aggregate_failures do
    create(:variable, :secret, environment:, key: "token", value: "supersecret")
    stub_request(:get, "https://api.example.com/items").to_return(status: 200, headers: { "Set-Cookie" => ["a=1; Path=/", "echo=supersecret; Path=/"] })

    expect(result.record.set_cookies).to eq(["a=1; Path=/", "echo=#{ApiClient::Masker::MASK}; Path=/"])
  end

  describe "with the cookie jar" do
    let(:jar) { ApiClient::CookieJar.new(project: api_request.project, environment:) }

    before { jar.store("https://api.example.com/items", "stored=1; Path=/") }

    it "sends the stored cookies and keeps the ones the response sets", :aggregate_failures do
      stub = stub_request(:get, "https://api.example.com/items").with(headers: { "Cookie" => "stored=1" }).to_return(status: 200, headers: { "Set-Cookie" => "fresh=2; Path=/" })

      result

      expect(stub).to have_been_requested
      expect(jar.header("https://api.example.com/items")).to eq("stored=1; fresh=2")
    end

    it "is bypassed when the request turns it off", :aggregate_failures do
      api_request.update!(settings: { use_cookie_jar: false })
      stub = stub_request(:get, "https://api.example.com/items").with { |request| !request.headers.key?("Cookie") }.to_return(status: 200, headers: { "Set-Cookie" => "fresh=2; Path=/" })

      result

      expect(stub).to have_been_requested
      expect(jar.header("https://api.example.com/items")).to eq("stored=1")
      expect(result.record.set_cookies).to eq(["fresh=2; Path=/"])
    end
  end

  it "masks secrets in everything stored", :aggregate_failures do
    create(:variable, :secret, environment:, key: "token", value: "supersecret")
    api_request.update!(headers: [{ "key" => "X-Token", "value" => "{{token}}" }, { "key" => "Authorization", "value" => "Bearer abc" }])
    stub_request(:get, api_request.url).to_return(status: 302, body: "echo supersecret", headers: { "Location" => "/next?t=supersecret", "Content-Type" => "text/plain" })
    stub_request(:get, "https://api.example.com/next?t=supersecret").to_return(status: 200, body: "echo supersecret")

    expect(execution.response_body).to eq("echo #{ApiClient::Masker::MASK}")
    expect(execution.request_headers).to include(["X-Token", ApiClient::Masker::MASK], ["Authorization", ApiClient::Masker::MASK])
    expect(execution.redirects).to contain_exactly(include("status" => 302, "to" => "https://api.example.com/next?t=#{ApiClient::Masker::MASK}"))
  end

  describe "secret masking edge cases" do
    let(:mask) { ApiClient::Masker::MASK }

    before { create(:variable, :secret, environment:, key: "token", value: "supersecret") }

    it "masks the secret in the url, the request body and the error message", :aggregate_failures do
      api_request.update!(http_method: "POST", url: "https://api.example.com/items?t={{token}}", body_type: "json", body: '{"k":"{{token}}"}')
      stub_request(:post, "https://api.example.com/items?t=supersecret").to_raise(Faraday::ConnectionFailed.new(IOError.new("failed for supersecret")))

      expect(execution).to have_attributes(url: "https://api.example.com/items?t=#{mask}", request_body: %({"k":"#{mask}"}), error_message: "failed for #{mask}")
    end

    it "masks the secret in response headers, set cookies and the body", :aggregate_failures do
      stub_request(:get, api_request.url).to_return(status: 200, body: "supersecret", headers: { "X-Echo" => "supersecret", "Set-Cookie" => "s=supersecret", "Content-Type" => "text/plain" })

      expect(execution.response_headers).to include(["x-echo", mask])
      expect(execution.set_cookies).to eq(["s=#{mask}"])
      expect(execution.response_body).to eq(mask)
    end

    it "masks the secret echoed back url encoded or in Basic form", :aggregate_failures do
      stub_request(:get, api_request.url).to_return(status: 200, body: "#{CGI.escape("supersecret")} #{Base64.strict_encode64("user:supersecret")} #{Base64.strict_encode64("supersecret")}", headers: { "Content-Type" => "text/plain" })

      expect(execution.response_body).not_to include("supersecret")
      expect(execution.response_body).to include(mask)
    end

    it "never keeps the secret in the stashed or saved copies", :aggregate_failures do
      stub_request(:get, api_request.url).to_return(status: 200, body: "supersecret", headers: { "Content-Type" => "text/plain" })

      pending = RequestExecution.pending(execution.id)

      expect(pending.attributes.values.map(&:to_s).join).not_to include("supersecret")
    end

    it "masks a non ASCII secret even when headers carry raw bytes", :aggregate_failures do
      create(:variable, :secret, environment:, key: "clave", value: "contraseña")
      stub_request(:get, api_request.url).to_return(status: 200, body: "ok", headers: { "X-Name" => "café contraseña".b })

      expect(execution.error_kind).to be_nil
      expect(execution.response_headers).to include(["x-name", "café #{mask}"])
    end
  end

  it "does not send cookies stored by another project", :aggregate_failures do
    ApiClient::CookieJar.new(project: create(:project)).store("https://api.example.com/items", "other=1; Path=/")
    stub = stub_request(:get, "https://api.example.com/items").with { |request| !request.headers.key?("Cookie") }.to_return(status: 200)

    result

    expect(stub).to have_been_requested
  end

  it "survives a server sending an absurd cookie lifetime", :aggregate_failures do
    stub_request(:get, "https://api.example.com/items").to_return(status: 200, headers: { "Set-Cookie" => "a=1; Path=/; Max-Age=99999999999999999999" })

    expect(execution).to have_attributes(status: 200, error_kind: nil)
  end

  it "stores text bodies with a byte order mark and unicode intact", :aggregate_failures do
    stub_request(:get, api_request.url).to_return(status: 200, body: "\uFEFF{\"name\":\"ñandú 🦤\"}", headers: { "Content-Type" => "application/json; charset=utf-8" })

    expect(execution.response_body).to eq("\uFEFF{\"name\":\"ñandú 🦤\"}")
  end

  it "treats structured syntax suffix and charset parameters as text", :aggregate_failures do
    stub_request(:get, api_request.url).to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/problem+json; charset=utf-8" })

    expect(execution).to have_attributes(response_body: "{}", body_omitted: false)
  end

  it "stores a blank body" do
    stub_request(:get, api_request.url).to_return(status: 204)

    expect(execution).to have_attributes(response_body: "", body_omitted: false)
  end

  it "stores bodies without content type as text" do
    stub_request(:get, api_request.url).to_return(status: 200, body: "plain")

    expect(execution.response_body).to eq("plain")
  end

  it "omits binary bodies", :aggregate_failures do
    stub_request(:get, api_request.url).to_return(status: 200, body: "\x89PNG\x00".b, headers: { "Content-Type" => "image/png" })

    expect(execution).to have_attributes(response_body: nil, body_omitted: true)
  end

  it "omits bodies that are not valid UTF-8" do
    stub_request(:get, api_request.url).to_return(status: 200, body: "\xFF\xFE".b, headers: { "Content-Type" => "text/plain" })

    expect(execution.body_omitted).to be(true)
  end

  it "omits text bodies with null bytes" do
    stub_request(:get, api_request.url).to_return(status: 200, body: "a\u0000b", headers: { "Content-Type" => "text/plain" })

    expect(execution.body_omitted).to be(true)
  end

  it "omits non-text content types" do
    stub_request(:get, api_request.url).to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/octet-stream" })

    expect(execution.body_omitted).to be(true)
  end

  it "stores bodies over 1 MB whole", :aggregate_failures do
    stub_request(:get, api_request.url).to_return(status: 200, body: "a" * (1.megabyte + 10), headers: { "Content-Type" => "text/plain" })

    expect(execution.response_body.bytesize).to eq(1.megabyte + 10)
    expect(execution.body_truncated).to be(false)
  end

  it "flags bodies cut at the read limit", :aggregate_failures do
    stub_request(:get, api_request.url).to_return(status: 200, body: "a" * (ApiClient::Requests::Dispatch::BODY_LIMIT + 10), headers: { "Content-Type" => "text/plain" })

    expect(execution.response_body.bytesize).to eq(ApiClient::Requests::Dispatch::BODY_LIMIT)
    expect(execution.body_truncated).to be(true)
  end

  it "records transport errors" do
    stub_request(:get, api_request.url).to_raise(Errno::ECONNREFUSED)

    expect(execution).to have_attributes(error_kind: "refused", status: nil)
  end

  it "records invalid requests without sending them", :aggregate_failures do
    api_request.update!(url: "{{missing}}/x")

    expect(result).to be_success
    expect(execution).to have_attributes(error_kind: "invalid_request", url: "{{missing}}/x", unresolved_variables: ["missing"], status: nil)
  end

  it "does not touch the history" do
    stub_request(:get, api_request.url).to_return(status: 200)

    expect { result }.not_to change(RequestExecution, :count)
  end

  describe "with pending edits" do
    let(:attributes) { { url: "https://api.example.com/edited" } }

    it "saves them before sending", :aggregate_failures do
      stub_request(:get, "https://api.example.com/edited").to_return(status: 200)

      expect(execution.url).to eq("https://api.example.com/edited")
      expect(api_request.reload.url).to eq("https://api.example.com/edited")
    end

    it "returns the failure when the edits are invalid" do
      invalid = described_class.call(api_request:, environment:, user:, attributes: { name: "" })

      expect(invalid).to be_failure
      expect(invalid.record).to eq(api_request)
    end
  end
end
