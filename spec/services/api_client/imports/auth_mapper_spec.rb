require "rails_helper"

RSpec.describe ApiClient::Imports::AuthMapper do
  let(:warnings) { [] }

  it "keeps a known strategy and stringifies its config", :aggregate_failures do
    result = described_class.call("basic", { username: "u", password: nil }, warnings)
    expect(result).to eq(auth_type: "basic", auth_config: { "username" => "u", "password" => "" })
    expect(warnings).to be_empty
  end

  it "maps blank and inherit to inherit, none to none", :aggregate_failures do
    expect(described_class.call(nil, {}, warnings)[:auth_type]).to eq("inherit")
    expect(described_class.call("inherit", {}, warnings)[:auth_type]).to eq("inherit")
    expect(described_class.call("none", {}, warnings)[:auth_type]).to eq("none")
  end

  it "falls back to inherit with a warning for unknown strategies", :aggregate_failures do
    expect(described_class.call("hawk", {}, warnings)).to eq(auth_type: "inherit", auth_config: {})
    expect(warnings).to eq([I18n.t("workbench.imports.warnings.auth_unsupported", type: "hawk")])
  end
end
