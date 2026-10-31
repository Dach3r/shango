require "rails_helper"

RSpec.describe ApiClient::Assertions::Describe do
  it "describes an assertion with only what it has", :aggregate_failures do
    expect(described_class.title({ "kind" => "assertion", "source" => "json", "target" => "$.id", "operator" => "equals", "expected" => "1" })).to eq("JSON $.id equals 1")
    expect(described_class.title({ "kind" => "assertion", "source" => "status", "target" => "", "operator" => "lt", "expected" => "500" })).to eq("Status code is less than 500")
  end

  it "describes an extractor and the warning about saving", :aggregate_failures do
    expect(described_class.title({ "kind" => "extractor", "source" => "json", "target" => "$.t", "variable" => "token" })).to eq("Set token from JSON $.t")
    expect(described_class.title({ "kind" => "extractor", "source" => "status", "variable" => "code" })).to eq("Set code from Status code")
    expect(described_class.title({ "kind" => "extractor", "variable" => nil })).to eq(I18n.t("workbench.automation.extractor_unsaved"))
  end

  it "uses the name of a script test, or says it is a script error", :aggregate_failures do
    expect(described_class.title({ "kind" => "script", "name" => "Status is 200" })).to eq("Status is 200")
    expect(described_class.title({ "kind" => "script", "name" => nil })).to eq(I18n.t("workbench.automation.script_error"))
  end

  it "shows what a script reported as it is, never as a translation key or a template", :aggregate_failures do
    expect(described_class.detail({ "kind" => "script", "error" => "expected 3 to equal 4" })).to eq("expected 3 to equal 4")
    expect(described_class.detail({ "kind" => "script", "error" => "not_found %{x}" })).to eq("not_found %{x}")
    expect(described_class.detail({ "kind" => "script", "error" => nil })).to be_nil
  end

  it "explains an error, or shows what a failed check got", :aggregate_failures do
    expect(described_class.detail({ "error" => "not_found" })).to eq(I18n.t("workbench.automation.errors.not_found"))
    expect(described_class.detail({ "error" => "custom message" })).to eq("custom message")
    expect(described_class.detail({ "status" => "failed", "actual" => "404" })).to eq("Got: 404")
    expect(described_class.detail({ "status" => "passed", "actual" => "200" })).to be_nil
    expect(described_class.detail({ "status" => "failed", "actual" => nil })).to be_nil
  end

  it "follows the current locale" do
    I18n.with_locale(:es) { expect(described_class.title({ "kind" => "assertion", "source" => "status", "operator" => "equals", "expected" => "200" })).to eq("Código de estado es igual a 200") }
  end
end
