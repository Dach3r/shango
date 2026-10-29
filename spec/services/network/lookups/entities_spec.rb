require "rails_helper"

RSpec.describe Network::Lookups::Entities do
  def vcard(**properties)
    ["vcard", [["version", {}, "text", "4.0"], *properties.map { |name, value| [name.to_s, {}, "text", value] }]]
  end

  let(:abuse) { { "roles" => ["abuse"], "vcardArray" => vcard(email: "abuse@registrar.example", tel: "tel:+1.5555550100", fn: "Abuse Desk") } }
  let(:registrar) { { "roles" => ["registrar"], "handle" => "292", "vcardArray" => vcard(fn: "MarkMonitor Inc."), "publicIds" => [{ "type" => "IANA Registrar ID", "identifier" => 292 }, "junk"], "entities" => [abuse] } }
  let(:registrant) { { "roles" => ["registrant"], "vcardArray" => vcard(fn: "Jane Doe", email: "jane@example.com") } }

  describe ".find" do
    it "finds an entity by role, also inside another one", :aggregate_failures do
      expect(described_class.find([registrant, registrar], "registrar")).to eq(registrar)
      expect(described_class.find([registrant, registrar], "abuse")).to eq(abuse)
    end

    it "finds nothing in what is not a list of entities", :aggregate_failures do
      expect(described_class.find(nil, "abuse")).to be_nil
      expect(described_class.find(["junk", { "roles" => "x" }], "abuse")).to be_nil
    end
  end

  describe ".registrar" do
    it "reads the name and the IANA id", :aggregate_failures do
      expect(described_class.registrar([registrar])).to eq(name: "MarkMonitor Inc.", iana_id: "292")
      expect(described_class.registrar([registrant])).to be_nil
    end

    it "falls back to the handle and has no id without public ids", :aggregate_failures do
      expect(described_class.registrar([{ "roles" => ["registrar"], "handle" => "H-1" }])).to eq(name: "H-1", iana_id: nil)
    end
  end

  describe ".abuse" do
    it "reads only the email and the phone", :aggregate_failures do
      expect(described_class.abuse([registrar])).to eq(email: "abuse@registrar.example", phone: "+1.5555550100")
      expect(described_class.abuse([registrant])).to be_nil
      expect(described_class.abuse([{ "roles" => ["abuse"] }])).to be_nil
    end
  end

  describe ".organization" do
    it "names the holder only when it is an organization", :aggregate_failures do
      org = { "roles" => ["registrant"], "vcardArray" => vcard(fn: "Google LLC", kind: "org") }

      expect(described_class.organization([org])).to eq("Google LLC")
      expect(described_class.organization([registrant])).to be_nil
      expect(described_class.organization([registrar])).to be_nil
    end
  end

  it "never reads a registrant's contact data" do
    expect(described_class.registrar([registrant])).to be_nil
    expect(described_class.abuse([registrant])).to be_nil
  end
end
