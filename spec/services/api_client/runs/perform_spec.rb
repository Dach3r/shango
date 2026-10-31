require "rails_helper"

RSpec.describe ApiClient::Runs::Perform do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:environment) { create(:environment, project:) }
  let(:collection) { create(:collection, project:) }
  let(:options) { {} }
  let(:pauses) { [] }
  let(:run) { ApiClient::Runs::Create.call(collection:, user:, environment:, options:).record }
  let(:result) { described_class.call(run:, pause: ->(seconds) { pauses << seconds }) }

  before do
    create(:membership, :owner, user:, project:)
    ActiveJob::Base.queue_adapter = :test
  end

  def request(name, url: "https://api.example.com/#{name}", **attributes)
    create(:api_request, collection:, name:, url:, **attributes)
  end

  def ok(path = "a", body: "{}")
    stub_request(:get, "https://api.example.com/#{path}").to_return(status: 200, body:, headers: { "Content-Type" => "application/json" })
  end

  it "sends the requests in order and records every outcome", :aggregate_failures do
    request("a", assertions: [{ source: "status", operator: "equals", expected: "200" }])
    request("b")
    stub_a = ok("a")
    stub_b = ok("b", body: "[1]")

    expect(result).to be_success
    run.reload
    expect(run).to be_completed
    expect(run).to have_attributes(passed_count: 2, failed_count: 0, started_at: be_present, finished_at: be_present)
    expect(run.items.map(&:status)).to eq(%w[passed passed])
    expect(run.items.first).to have_attributes(http_status: 200, url: "https://api.example.com/a", duration_ms: be >= 0)
    expect(run.items.first.test_results.pluck("status")).to eq(["passed"])
    expect(stub_a).to have_been_requested
    expect(stub_b).to have_been_requested
  end

  it "fails a request whose assertion fails and goes on", :aggregate_failures do
    request("a", assertions: [{ source: "status", operator: "equals", expected: "404" }])
    request("b")
    ok("a")
    ok("b")

    result
    run.reload

    expect(run).to be_completed
    expect(run).to have_attributes(passed_count: 1, failed_count: 1)
    expect(run.items.map(&:status)).to eq(%w[failed passed])
    expect(run).not_to be_successful
  end

  it "skips what follows the first failure when asked to stop", :aggregate_failures do
    request("a", assertions: [{ source: "status", operator: "equals", expected: "404" }])
    request("b")
    request("c")
    ok("a")
    later = ok("b")
    run.update!(options: run.options.merge("stop_on_failure" => true))

    result
    run.reload

    expect(run).to be_completed
    expect(run.items.map(&:status)).to eq(%w[failed skipped skipped])
    expect(later).not_to have_been_requested
  end

  it "fails a request that could not be sent", :aggregate_failures do
    request("a")
    stub_request(:get, "https://api.example.com/a").to_timeout

    result
    item = run.reload.items.first

    expect(item).to be_failed
    expect(item.error_kind).to be_present
    expect(run).to have_attributes(failed_count: 1)
  end

  it "fails a request that cannot be built", :aggregate_failures do
    request("a", url: "")

    result

    expect(run.reload.items.first).to have_attributes(status: "failed", error_kind: "invalid_request")
  end

  describe "variables" do
    let(:token_request) { request("login", extractors: [{ source: "json", target: "$.token", variable: "token" }]) }

    before do
      token_request
      request("use", url: "https://api.example.com/use/{{token}}")
      ok("login", body: { token: "abc" }.to_json)
      stub_request(:get, "https://api.example.com/use/abc").to_return(status: 200)
    end

    it "hands what an extractor found to the requests after it, without touching the environment", :aggregate_failures do
      result

      expect(run.reload.items.map(&:status)).to eq(%w[passed passed])
      expect(environment.variables.reload).to be_empty
    end

    it "saves it to the environment when the run asks to", :aggregate_failures do
      run.update!(options: run.options.merge("persist_variables" => true))

      result

      expect(run.reload.items.map(&:status)).to eq(%w[passed passed])
      expect(environment.variables.find_by(key: "token")&.value).to eq("abc")
    end

    it "masks a secret extracted value wherever it shows up", :aggregate_failures do
      token_request.update!(extractors: [{ source: "json", target: "$.token", variable: "token", secret: true }])

      result

      expect(run.reload.items.last.url).to eq("https://api.example.com/use/#{ApiClient::Masker::MASK}")
    end
  end

  it "carries what scripts write to the requests after them, without touching the environment", :aggregate_failures do
    request("first", post_response_script: "pm.variables.set('run_var', 'from-script'); pm.environment.set('env_var', 'e');")
    request("second", url: "https://api.example.com/second/{{run_var}}/{{env_var}}")
    ok("first")
    stub_request(:get, "https://api.example.com/second/from-script/e").to_return(status: 200)

    result

    expect(run.reload.items.map(&:status)).to eq(%w[passed passed])
    expect(environment.variables.reload).to be_empty
  end

  it "counts a failing script test as a failed request", :aggregate_failures do
    request("a", post_response_script: "pm.test('nope', () => pm.expect(1).to.equal(2));")
    ok("a")

    result

    expect(run.reload.items.first).to be_failed
    expect(run.items.first.test_results.first).to include("kind" => "script", "status" => "failed")
  end

  it "fails a request whose pre-request script throws, without sending it", :aggregate_failures do
    request("a", pre_request_script: "throw new Error('stop');")
    stub = ok("a")

    result

    expect(run.reload.items.first).to have_attributes(status: "failed", error_kind: "script_error")
    expect(stub).not_to have_been_requested
  end

  it "does not touch the history or the latest responses of the requests", :aggregate_failures do
    request("a")
    ok("a")

    expect { result }.not_to change { [RequestExecution.count, LatestExecution.count] }
  end

  describe "cancelling" do
    it "stops after the request that was running and skips the rest", :aggregate_failures do
      request("a")
      request("b")
      stub_request(:get, "https://api.example.com/a").to_return do
        ApiClient::Runs::Cancel.call(run: CollectionRun.find(run.id))
        { status: 200 }
      end
      later = ok("b")

      result
      run.reload

      expect(run).to be_cancelled
      expect(run.items.map(&:status)).to eq(%w[skipped skipped])
      expect(later).not_to have_been_requested
    end

    it "skips the request that reports it was cancelled in flight", :aggregate_failures do
      request("a")
      cancelled = RequestExecution.new(error_kind: "cancelled", test_results: [], url: "https://api.example.com/a")
      allow(ApiClient::Requests::Dispatch).to receive(:call).and_return(Result.success(cancelled, variables: {}, secrets: []))

      result

      expect(run.reload.items.first).to have_attributes(status: "skipped", error_kind: "cancelled")
    end

    it "does not run a run that is no longer queued" do
      request("a")
      run.start!

      expect(described_class.call(run: CollectionRun.find(run.id))).to be_failure
    end
  end

  describe "when something is wrong" do
    it "marks the run as failed when the user lost access", :aggregate_failures do
      request("a")
      ok("a")
      create(:membership, :owner, project:)
      Membership.find_by(user:, project:).update!(revoked_at: Time.current)

      expect(result).to be_failure
      expect(run.reload).to have_attributes(status: "failed", error: "access_revoked")
      expect(run.items.map(&:status)).to eq(["pending"])
    end

    it "skips a request that was deleted after the run was planned", :aggregate_failures do
      doomed = request("a")
      request("b")
      ok("b")
      run
      doomed.destroy!

      result

      expect(run.reload.items.map { |item| [item.status, item.error_kind] }).to eq([%w[skipped request_deleted], ["passed", nil]])
    end

    it "leaves a run that was cancelled meanwhile as cancelled when the job breaks", :aggregate_failures do
      request("a")
      allow(ApiClient::Requests::Dispatch).to receive(:call) do
        ApiClient::Runs::Cancel.call(run: CollectionRun.find(run.id))
        raise "boom"
      end
      allow(Rails.logger).to receive(:error)

      expect(result).to be_failure
      expect(run.reload).to be_cancelled
    end

    it "marks the run as failed on an unexpected error and logs it", :aggregate_failures do
      request("a")
      allow(ApiClient::Requests::Dispatch).to receive(:call).and_raise("boom")
      allow(Rails.logger).to receive(:error)

      expect(result).to be_failure
      expect(run.reload).to have_attributes(status: "failed", error: "unexpected")
      expect(Rails.logger).to have_received(:error).with(/boom/)
    end
  end

  describe "pacing and live updates" do
    it "waits between requests, not before the first", :aggregate_failures do
      request("a")
      request("b")
      ok("a")
      ok("b")
      run.update!(options: run.options.merge("delay_ms" => 500))

      result

      expect(pauses).to eq([0.5])
    end

    it "does not wait without a delay" do
      request("a")
      request("b")
      ok("a")
      ok("b")

      result

      expect(pauses).to be_empty
    end

    it "tells the open run page to refresh after every request" do
      request("a")
      ok("a")
      allow(Turbo::StreamsChannel).to receive(:broadcast_refresh_to)

      result

      expect(Turbo::StreamsChannel).to have_received(:broadcast_refresh_to).with(run).at_least(:twice)
    end

    it "sleeps for real by default" do
      request("a")
      request("b")
      ok("a")
      ok("b")
      run.update!(options: run.options.merge("delay_ms" => 100))
      allow_any_instance_of(described_class).to receive(:sleep)

      expect(described_class.call(run:)).to be_success
    end
  end
end
