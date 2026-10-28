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
end
