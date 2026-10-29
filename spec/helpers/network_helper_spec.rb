require "rails_helper"

RSpec.describe NetworkHelper do
  describe "#port_preset_options" do
    it "lists the common preset, one per group of services, and custom last", :aggregate_failures do
      options = helper.port_preset_options

      expect(options.first).to eq([I18n.t("network.ports.presets.common"), "common"])
      expect(options).to include(["Web (80, 443, 8080, 8443)", "80, 443, 8080, 8443"])
      expect(options.last).to eq([I18n.t("network.ports.presets.custom"), "custom"])
    end
  end

  describe "#port_preset_options with a typed list" do
    it "labels the custom option with it" do
      expect(helper.port_preset_options(custom: "22, 80").last).to eq(["22, 80", "custom"])
    end
  end

  describe "#port_preset_for" do
    it "finds the preset matching what is typed", :aggregate_failures do
      expect(helper.port_preset_for("common")).to eq("common")
      expect(helper.port_preset_for(" 80, 443, 8080, 8443 ")).to eq("80, 443, 8080, 8443")
    end

    it "falls back to custom, also for the word custom", :aggregate_failures do
      expect(helper.port_preset_for("22, 80")).to eq("custom")
      expect(helper.port_preset_for("custom")).to eq("custom")
      expect(helper.port_preset_for(nil)).to eq("custom")
    end
  end

  describe "#email_section_status" do
    def status(section, *findings)
      helper.email_section_status({ findings: findings.map { |key, tone| { key:, tone:, args: {} } } }, section)
    end

    it "is healthy without findings of the section, whatever the others have", :aggregate_failures do
      expect(status("spf")).to eq(:healthy)
      expect(status("spf", ["dmarc.policy_none", "warn"])).to eq(:healthy)
    end

    it "takes the worst tone of the findings of the section", :aggregate_failures do
      expect(status("dmarc", ["dmarc.policy_none", "warn"])).to eq(:attention)
      expect(status("dmarc", ["dmarc.policy_none", "warn"], ["dmarc.invalid_policy", "bad"])).to eq(:broken)
    end

    it "is missing when the record is not there" do
      expect(status("spf", ["spf.missing", "bad"])).to eq(:missing)
    end
  end

  describe "#lookup_expiry_status" do
    it "tells expired, expiring and valid domains", :aggregate_failures do
      expect(helper.lookup_expiry_status(-1)).to eq(:expired)
      expect(helper.lookup_expiry_status(0)).to eq(:expiring)
      expect(helper.lookup_expiry_status(Network::Lookups::Domain::EXPIRING_DAYS)).to eq(:expiring)
      expect(helper.lookup_expiry_status(Network::Lookups::Domain::EXPIRING_DAYS + 1)).to eq(:valid)
    end
  end
end
