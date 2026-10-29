require "rails_helper"

RSpec.describe Network::EmailChecks::Tags do
  it "reads tag=value pairs, ignoring spacing, case of the tag and empty parts", :aggregate_failures do
    expect(described_class.parse("v=DMARC1; P=reject ;; rua = mailto:a@example.com; ")).to eq("v" => "DMARC1", "p" => "reject", "rua" => "mailto:a@example.com")
    expect(described_class.parse("v=DKIM1; p=")).to eq("v" => "DKIM1", "p" => "")
  end

  it "skips parts without an equals sign" do
    expect(described_class.parse("junk; p=x")).to eq("p" => "x")
  end
end
