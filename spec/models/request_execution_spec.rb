require "rails_helper"

RSpec.describe RequestExecution do
  subject(:execution) { build(:request_execution) }

  describe "#error?" do
    it "reflects error_kind", :aggregate_failures do
      expect(execution).not_to be_error
      execution.error_kind = "timeout"
      expect(execution).to be_error
    end
  end

  describe "#status_class" do
    it "is error when failed" do
      execution.error_kind = "timeout"

      expect(execution.status_class).to eq(:error)
    end

    {
      200 => :success,
      302 => :success,
      404 => :client_error,
      100 => :success,
      399 => :success,
      400 => :client_error,
      499 => :client_error,
      500 => :server_error,
      599 => :server_error
    }.each do |status, expected|
      it "maps #{status} to #{expected}" do
        execution.status = status

        expect(execution.status_class).to eq(expected)
      end
    end
  end

  describe "pending executions" do
    let(:user) { create(:user) }
    let(:api_request) { create(:api_request) }

    it "restores a stashed execution by id", :aggregate_failures do
      execution = build(:request_execution, user:, api_request:, id: SecureRandom.uuid, url: "https://api.example.com/a")

      expect(execution.stash).to eq(execution)
      expect(described_class.pending(execution.id)).to have_attributes(id: execution.id, url: "https://api.example.com/a")
    end

    it "cuts oversized bodies before stashing them", :aggregate_failures do
      big = "é" * (described_class::STORED_BODY_BYTES / 2 + 100)
      execution = build(:request_execution, user:, api_request:, id: SecureRandom.uuid, response_body: big, request_body: big, body_truncated: false)
      execution.stash

      restored = described_class.pending(execution.id)
      expect(restored.response_body.bytesize).to be <= described_class::STORED_BODY_BYTES
      expect(restored.request_body.bytesize).to be <= described_class::STORED_BODY_BYTES
      expect(restored.body_truncated).to be(true)
      expect(execution.response_body).to eq(big)
    end

    it "never cuts a multibyte character in half", :aggregate_failures do
      big = "€" * (described_class::STORED_BODY_BYTES / 3 + 10)
      execution = build(:request_execution, user:, api_request:, id: SecureRandom.uuid, response_body: big)
      execution.stash

      restored = described_class.pending(execution.id)
      expect(restored.response_body).to be_valid_encoding
      expect(restored.response_body).to eq("€" * (described_class::STORED_BODY_BYTES / 3))
    end

    it "does not flag the response as truncated when only the request body was cut", :aggregate_failures do
      execution = build(:request_execution, user:, api_request:, id: SecureRandom.uuid, request_body: "a" * (described_class::STORED_BODY_BYTES + 1), response_body: "ok", body_truncated: false)
      execution.stash

      expect(described_class.pending(execution.id)).to have_attributes(body_truncated: false, response_body: "ok")
    end

    it "keeps a body of exactly the limit whole" do
      execution = build(:request_execution, user:, api_request:, id: SecureRandom.uuid, response_body: "a" * described_class::STORED_BODY_BYTES, body_truncated: false)
      execution.stash

      expect(described_class.pending(execution.id)).to have_attributes(body_truncated: false)
    end

    it "keeps small bodies and the truncation flag as they are", :aggregate_failures do
      execution = build(:request_execution, user:, api_request:, id: SecureRandom.uuid, response_body: "ok", request_body: nil, body_truncated: false)
      execution.stash

      expect(described_class.pending(execution.id)).to have_attributes(response_body: "ok", request_body: nil, body_truncated: false)
    end

    it "is nil for unknown ids" do
      expect(described_class.pending(SecureRandom.uuid)).to be_nil
    end
  end

  describe ".unsaved_for" do
    let(:user) { create(:user) }
    let(:api_request) { create(:api_request) }

    it "ignores saved runs", :aggregate_failures do
      create(:request_execution, api_request:, user:)
      expect(described_class.unsaved_for(api_request, user)).to be_nil

      stashed = build(:request_execution, id: SecureRandom.uuid, api_request:, user:).stash
      expect(described_class.unsaved_for(api_request, user).id).to eq(stashed.id)
    end
  end

  describe ".latest_for" do
    let(:user) { create(:user) }
    let(:api_request) { create(:api_request) }

    it "prefers the freshest stashed run over the saved ones", :aggregate_failures do
      create(:request_execution, api_request:, user:, url: "https://api.example.com/saved")
      stashed = build(:request_execution, id: SecureRandom.uuid, api_request:, user:, url: "https://api.example.com/stashed").stash

      expect(described_class.latest_for(api_request, user).id).to eq(stashed.id)
    end

    it "falls back to the newest saved run of the user", :aggregate_failures do
      create(:request_execution, api_request:, user: create(:user), url: "https://api.example.com/other")
      create(:request_execution, api_request:, user:, url: "https://api.example.com/old", created_at: 1.day.ago)
      latest = create(:request_execution, api_request:, user:, url: "https://api.example.com/new")

      expect(described_class.latest_for(api_request, user)).to eq(latest)
    end

    it "does not show a stashed run to another user", :aggregate_failures do
      build(:request_execution, id: SecureRandom.uuid, api_request:, user:).stash

      expect(described_class.latest_for(api_request, create(:user))).to be_nil
    end

    it "does not mix up the stashed runs of different requests" do
      build(:request_execution, id: SecureRandom.uuid, api_request:, user:).stash

      expect(described_class.latest_for(create(:api_request), user)).to be_nil
    end

    it "keeps only the newest stashed run of a request", :aggregate_failures do
      first = build(:request_execution, id: SecureRandom.uuid, api_request:, user:).stash
      second = build(:request_execution, id: SecureRandom.uuid, api_request:, user:).stash

      expect(described_class.latest_for(api_request, user).id).to eq(second.id)
      expect(described_class.pending(first.id)).to be_nil
      expect(LatestExecution.count).to eq(1)
    end

    it "survives a cache wipe" do
      stashed = build(:request_execution, id: SecureRandom.uuid, api_request:, user:).stash
      Rails.cache.clear

      expect(described_class.latest_for(api_request, user).id).to eq(stashed.id)
    end

    it "shows the stashed run of a request that is still a draft", :aggregate_failures do
      draft = create(:request_draft, user:)
      unsaved = ApiClient::Drafts::Build.call(draft:)
      stashed = build(:request_execution, id: SecureRandom.uuid, api_request: unsaved, project: draft.project, user:, url: "https://api.example.com/draft").stash

      expect(described_class.latest_for(unsaved, user)).to have_attributes(id: stashed.id, api_request_id: draft.id, url: "https://api.example.com/draft")
      expect(LatestExecution.last).to have_attributes(request_draft_id: draft.id, api_request_id: nil)
    end

    it "is nil without any response" do
      expect(described_class.latest_for(api_request, user)).to be_nil
    end
  end

  describe "#status_class without a status" do
    it "is a server error when there is neither a status nor an error" do
      execution.status = nil

      expect(execution.status_class).to eq(:server_error)
    end
  end

  describe ".recent" do
    it "orders newest first" do
      old = create(:request_execution, created_at: 1.day.ago)
      recent = create(:request_execution, created_at: 1.minute.ago)

      expect(described_class.recent).to eq([recent, old])
    end
  end
end
