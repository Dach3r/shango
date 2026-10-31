require "rails_helper"

RSpec.describe AutomationHelper, type: :helper do
  describe "#outcome_title" do
    it "describes an assertion with its target and expected value" do
      outcome = { "kind" => "assertion", "source" => "json", "target" => "$.id", "operator" => "equals", "expected" => "1" }

      expect(helper.outcome_title(outcome)).to eq("JSON $.id equals 1")
    end

    it "leaves out what the assertion does not have" do
      expect(helper.outcome_title({ "kind" => "assertion", "source" => "json", "target" => "$.id", "operator" => "exists", "expected" => "" })).to eq("JSON $.id exists")
    end

    it "describes an extractor, and the warning about saving", :aggregate_failures do
      expect(helper.outcome_title({ "kind" => "extractor", "source" => "json", "target" => "$.t", "variable" => "token" })).to eq("Set token from JSON $.t")
      expect(helper.outcome_title({ "kind" => "extractor", "source" => "status", "target" => "", "variable" => "code" })).to eq("Set code from Status code")
      expect(helper.outcome_title({ "kind" => "extractor", "variable" => nil, "error" => "not_permitted" })).to eq(I18n.t("workbench.automation.extractor_unsaved"))
    end

    it "uses the name of any other kind" do
      expect(helper.outcome_title({ "kind" => "script", "name" => "Status is 200" })).to eq("Status is 200")
    end
  end

  describe "#outcome_detail" do
    it "explains an error, falling back to the key", :aggregate_failures do
      expect(helper.outcome_detail({ "error" => "not_found" })).to eq(I18n.t("workbench.automation.errors.not_found"))
      expect(helper.outcome_detail({ "error" => "custom message" })).to eq("custom message")
    end

    it "shows what a failed check got, and nothing for a pass", :aggregate_failures do
      expect(helper.outcome_detail({ "status" => "failed", "actual" => "404" })).to eq("Got: 404")
      expect(helper.outcome_detail({ "status" => "passed", "actual" => "200" })).to be_nil
      expect(helper.outcome_detail({ "status" => "failed", "actual" => nil })).to be_nil
    end
  end

  it "picks an icon and a tone per status", :aggregate_failures do
    expect(helper.outcome_icon({ "status" => "passed" })).to eq("circle-check")
    expect(helper.outcome_icon({ "status" => "failed" })).to eq("circle-x")
    expect(helper.outcome_icon({ "status" => "warning" })).to eq("triangle-alert")
    expect(helper.outcome_tone({ "status" => "passed" })).to include("emerald")
    expect(helper.outcome_tone({ "status" => "failed" })).to eq("text-danger")
    expect(helper.outcome_tone({ "status" => "warning" })).to include("amber")
  end
end
