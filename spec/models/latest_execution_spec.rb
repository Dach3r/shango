require "rails_helper"

RSpec.describe LatestExecution do
  let(:user) { create(:user) }
  let(:api_request) { create(:api_request) }

  def execution(**attributes)
    build(:request_execution, id: SecureRandom.uuid, api_request:, user:, response_body: "hi", **attributes)
  end

  describe ".keep" do
    it "overwrites the previous row of the same user and request", :aggregate_failures do
      described_class.keep(execution)
      latest = execution(response_body: "newer")
      described_class.keep(latest)

      expect(described_class.count).to eq(1)
      expect(described_class.last.execution).to have_attributes(id: latest.id, response_body: "newer")
    end

    it "keeps a row per user", :aggregate_failures do
      described_class.keep(execution)
      described_class.keep(execution(user: create(:user)))

      expect(described_class.count).to eq(2)
    end

    it "retries when a concurrent run took the slot first", :aggregate_failures do
      first = execution
      taken = false
      allow(described_class).to receive(:slot).and_wrap_original do |original, *args|
        row = original.call(*args)
        unless taken
          taken = true
          create(:latest_execution, project: first.project, user:, api_request:)
        end
        row
      end

      described_class.keep(first)

      expect(described_class.count).to eq(1)
      expect(described_class.last.execution_id).to eq(first.id)
    end

    it "encrypts the payload at rest" do
      described_class.keep(execution(response_body: "top-secret-body"))

      expect(described_class.connection.select_value("SELECT payload FROM latest_executions")).not_to include("top-secret-body")
    end
  end

  describe "#execution" do
    it "points at the request the row belongs to even if the payload says otherwise" do
      row = create(:latest_execution, user:, api_request:, payload: { "api_request_id" => SecureRandom.uuid, "url" => "https://a.test" }.to_json)

      expect(row.execution).to have_attributes(api_request_id: api_request.id, url: "https://a.test")
    end
  end
end
