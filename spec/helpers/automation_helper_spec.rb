require "rails_helper"

RSpec.describe AutomationHelper, type: :helper do
  it "words an outcome through ApiClient::Assertions::Describe", :aggregate_failures do
    outcome = { "kind" => "assertion", "source" => "json", "target" => "$.id", "operator" => "exists", "expected" => "", "status" => "failed", "error" => "not_found" }

    expect(helper.outcome_title(outcome)).to eq("JSON $.id exists")
    expect(helper.outcome_detail(outcome)).to eq(I18n.t("workbench.automation.errors.not_found"))
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
