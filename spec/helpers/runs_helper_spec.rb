require "rails_helper"

RSpec.describe RunsHelper, type: :helper do
  describe "#run_label and #run_tone" do
    it "shows the state, and failures for a completed run", :aggregate_failures do
      expect(helper.run_label(build(:collection_run))).to eq("Queued")
      expect(helper.run_tone(build(:collection_run))).to eq(described_class::RUN_TONES["queued"])

      done = create(:collection_run, :completed)
      expect(helper.run_label(done)).to eq("Completed")
      expect(helper.run_tone(done)).to include("emerald")

      done.failed_count = 2
      expect(helper.run_label(done)).to eq("Completed with failures")
      expect(helper.run_tone(done)).to include("danger")
    end
  end

  it "picks an icon and a tone for every item status", :aggregate_failures do
    CollectionRunItem.statuses.each_key do |status|
      item = create(:collection_run_item).tap { |record| record.update_columns(status:) }

      expect(helper.item_icon(item)).to be_present
      expect(helper.item_tone(item)).to be_present
    end
  end

  describe "#run_duration" do
    it "shows a dash before it started, milliseconds under a second and seconds after", :aggregate_failures do
      expect(helper.run_duration(build(:collection_run))).to eq("—")
      expect(helper.run_duration(build(:collection_run, started_at: Time.current, finished_at: 0.25.seconds.from_now))).to match(/\A\d+ ms\z/)
      expect(helper.run_duration(build(:collection_run, started_at: 3.seconds.ago, finished_at: Time.current))).to eq("3.0 s")
    end
  end

  describe "#run_progress" do
    it "is the share of finished requests", :aggregate_failures do
      expect(helper.run_progress(build(:collection_run, total_count: 0))).to eq(0)
      expect(helper.run_progress(build(:collection_run, total_count: 4, passed_count: 1, failed_count: 2))).to eq(75)
    end
  end
end
