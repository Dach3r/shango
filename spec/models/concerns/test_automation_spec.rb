require "rails_helper"

RSpec.describe TestAutomation do
  let(:api_request) { build(:api_request) }

  describe "assertions" do
    it "keeps valid rows with a generated id", :aggregate_failures do
      api_request.assertions = [{ source: "status", operator: "equals", expected: "200" }, { source: "json", target: " $.id ", operator: "exists", enabled: "0" }]

      expect(api_request.assertions).to match([
        { "id" => match(/\A\h{8}\z/), "enabled" => true, "source" => "status", "target" => "", "operator" => "equals", "expected" => "200" },
        { "id" => match(/\A\h{8}\z/), "enabled" => false, "source" => "json", "target" => "$.id", "operator" => "exists", "expected" => "" }
      ])
    end

    it "accepts the hash of rows a form posts and keeps a valid id", :aggregate_failures do
      api_request.assertions = { "0" => { id: "abcdef12", source: "status", operator: "lt", expected: "300" } }

      expect(api_request.assertions.first).to include("id" => "abcdef12")
    end

    it "drops unknown, incomplete and malformed rows", :aggregate_failures do
      api_request.assertions = [
        { source: "nope", operator: "equals", expected: "1" }, { source: "status", operator: "exists" }, { source: "status", operator: "equals", expected: "" },
        { source: "json", operator: "exists", target: "" }, "junk", { source: "body", operator: "is_empty" }
      ]

      expect(api_request.assertions.pluck("source")).to eq(["body"])
    end

    it "limits the rows and the length of target and expected", :aggregate_failures do
      api_request.assertions = Array.new(60) { { source: "body", operator: "contains", expected: "x" * 2_000 } }

      expect(api_request.assertions.size).to eq(ApiClient::Assertions::Catalog::MAX_ROWS)
      expect(api_request.assertions.first["expected"].length).to eq(described_class::MAX_EXPECTED)
    end

    it "is normalized on validation" do
      api_request = create(:api_request)
      api_request.update_columns(assertions: [{ "source" => "nope" }])

      expect { api_request.reload.valid? }.to change { api_request.assertions }.to([])
    end
  end

  describe "extractors" do
    it "keeps valid rows", :aggregate_failures do
      api_request.extractors = [{ source: "json", target: "$.token", variable: " token ", secret: "1" }, { source: "status", variable: "code" }]

      expect(api_request.extractors).to match([
        { "id" => match(/\A\h{8}\z/), "enabled" => true, "source" => "json", "target" => "$.token", "variable" => "token", "secret" => true },
        { "id" => match(/\A\h{8}\z/), "enabled" => true, "source" => "status", "target" => "", "variable" => "code", "secret" => false }
      ])
    end

    it "drops rows without a variable, a known source or a needed target", :aggregate_failures do
      api_request.extractors = [{ source: "json", target: "$.a", variable: "" }, { source: "nope", variable: "a" }, { source: "header", target: "", variable: "a" }]

      expect(api_request.extractors).to be_empty
    end

    it "is invalid with a variable name the environment would reject", :aggregate_failures do
      api_request.extractors = [{ source: "status", variable: "1 bad" }]

      expect(api_request).not_to be_valid
      expect(api_request.errors.full_messages.join).to include(I18n.t("activerecord.errors.models.api_request.attributes.base.invalid_extractor_variable"))
    end
  end
end
