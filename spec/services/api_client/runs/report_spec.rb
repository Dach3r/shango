require "rails_helper"

RSpec.describe ApiClient::Runs::Report do
  let(:run) { create(:collection_run, :completed, passed_count: 1, failed_count: 1, total_count: 4) }

  before do
    run.collection.update!(name: "Pets")
    item(status: "passed", name: "login", tests: [{ "kind" => "assertion", "status" => "passed", "source" => "status", "target" => "", "operator" => "equals", "expected" => "200" }])
    item(status: "failed", name: "create", tests: [
      { "kind" => "assertion", "status" => "failed", "source" => "json", "target" => "$.id", "operator" => "exists", "expected" => "", "error" => "not_found" },
      { "kind" => "extractor", "status" => "warning", "source" => "json", "target" => "$.id", "variable" => "id", "error" => "not_found" }
    ])
    item(status: "failed", name: "broken", error_kind: "timeout", error_message: "Timed out")
    item(status: "skipped", name: "later")
    item(status: "passed", name: "plain")
  end

  def item(status:, name:, tests: [], **attributes)
    record = create(:collection_run_item, collection_run: run, request_name: name, test_results: tests, http_status: 200, duration_ms: 12, url: "https://api.example.com/#{name}", **attributes.except(:status))
    record.update_columns(status:)
  end

  def report(format)
    described_class.call(run: run.reload, format:).record
  end

  describe "json" do
    subject(:data) { JSON.parse(report(:json)) }

    it "describes the run and every item", :aggregate_failures do
      expect(data).to include("id" => run.id, "status" => "completed", "collection" => "Pets", "folder" => nil, "environment" => nil, "total" => 4, "passed" => 1, "failed" => 1)
      expect(data["items"].pluck("name", "status")).to eq([%w[login passed], %w[create failed], %w[broken failed], %w[later skipped], %w[plain passed]])
      expect(data["items"].first).to include("method" => "GET", "url" => "https://api.example.com/login", "http_status" => 200, "duration_ms" => 12)
    end

    it "words the tests in the current locale", :aggregate_failures do
      expect(data["items"].first["tests"].first).to include("title" => "Status code equals 200", "status" => "passed")
      expect(data["items"][1]["tests"].first).to include("title" => "JSON $.id exists", "error" => "not_found")
    end

    it "has no times for a run that has not started", :aggregate_failures do
      queued = create(:collection_run)

      data = JSON.parse(described_class.call(run: queued, format: :json).record)

      expect(data).to include("status" => "queued", "started_at" => nil, "finished_at" => nil)
    end

    it "names the folder and the environment when there are" do
      run.update!(folder: create(:folder, collection: run.collection, name: "Auth"), environment: create(:environment, project: run.project, name: "Staging"))

      expect(data).to include("folder" => "Auth", "environment" => "Staging")
    end
  end

  describe "junit" do
    subject(:doc) { Nokogiri::XML(report(:junit)) }

    it "has a suite per request", :aggregate_failures do
      expect(doc.xpath("//testsuites/@name").text).to eq("Pets")
      expect(doc.xpath("//testsuite/@name").map(&:text)).to eq(%w[login create broken later plain])
    end

    it "counts what ran, what failed and what was skipped", :aggregate_failures do
      expect(doc.xpath("//testsuites/@tests").text).to eq("5")
      expect(doc.xpath("//testsuites/@failures").text).to eq("2")
      expect(doc.xpath("//testsuites/@skipped").text).to eq("1")
    end

    it "reports a failed assertion with its reason, and a request that could not be sent", :aggregate_failures do
      failures = doc.xpath("//failure/@message").map(&:text)

      expect(failures).to contain_exactly(I18n.t("workbench.automation.errors.not_found"), "Timed out")
    end

    it "gives a passing request without tests a single passing case, and a skipped one a skipped case", :aggregate_failures do
      expect(doc.xpath("//testsuite[@name='plain']/testcase/@name").map(&:text)).to eq(["plain"])
      expect(doc.xpath("//testsuite[@name='plain']//failure")).to be_empty
      expect(doc.xpath("//testsuite[@name='later']/testcase/skipped")).not_to be_empty
    end

    it "does not count an extractor that found nothing" do
      expect(doc.xpath("//testsuite[@name='create']/testcase").size).to eq(1)
    end

    it "falls back to the error key when there is no message" do
      run.items.find_by(request_name: "broken").update!(error_message: nil)

      expect(doc.xpath("//failure/@message").map(&:text)).to include("timeout")
    end
  end
end
