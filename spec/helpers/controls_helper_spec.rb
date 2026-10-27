require "rails_helper"

RSpec.describe ControlsHelper do
  describe "#bar_field_classes" do
    it "only shifts the background on focus" do
      expect(helper.bar_field_classes("w-24")).to include(ControlsHelper::BAR_FIELD, "w-24")
    end
  end

  describe "#field_classes" do
    it "adds full width by default", :aggregate_failures do
      expect(helper.field_classes).to include("w-full", ControlsHelper::FIELD)
      expect(helper.field_classes("mt-2")).to include("w-full", "mt-2")
    end

    it "skips full width when the caller sets sizing", :aggregate_failures do
      expect(helper.field_classes("w-24")).not_to include("w-full")
      expect(helper.field_classes("flex-1")).not_to include("w-full")
      expect(helper.field_classes("min-w-0")).not_to include("w-full")
    end
  end

  describe "#label_classes" do
    it "returns the label classes" do
      expect(helper.label_classes).to eq(ControlsHelper::LABEL)
    end
  end

  describe "#button_classes" do
    it "composes base, variant and extra", :aggregate_failures do
      expect(helper.button_classes).to include(ControlsHelper::BUTTON_BASE, ControlsHelper::BUTTONS[:secondary])
      expect(helper.button_classes(:danger, "mt-1")).to include(ControlsHelper::BUTTONS[:danger], "mt-1")
    end
  end
end
