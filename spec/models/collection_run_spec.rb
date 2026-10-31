require "rails_helper"

RSpec.describe CollectionRun do
  let(:run) { create(:collection_run) }

  describe "states" do
    it "starts queued and moves through its events", :aggregate_failures do
      expect(run).to be_queued

      run.start!
      expect(run).to be_running
      expect(run.started_at).to be_present

      run.finish!
      expect(run).to be_completed
      expect(run.finished_at).to be_present
    end

    it "can be cancelled or broken down while active, and only then", :aggregate_failures do
      run.cancel!
      expect(run).to be_cancelled
      expect(run.may_break_down?).to be(false)
      expect { run.start! }.to raise_error(AASM::InvalidTransition)

      broken = create(:collection_run, :running)
      broken.break_down!
      expect(broken).to be_failed
      expect(broken.finished_at).to be_present
    end

    it "does not take the status by assignment" do
      expect { run.status = "completed" }.to raise_error(AASM::NoDirectAssignmentError)
    end
  end

  describe "predicates" do
    it "knows when it is active, finished and successful", :aggregate_failures do
      expect(run).to be_active
      expect(run).not_to be_finished

      done = create(:collection_run, :completed)
      expect(done).to be_finished
      expect(done).not_to be_active
      expect(done).to be_successful

      done.failed_count = 1
      expect(done).not_to be_successful
    end

    it "reads its options and its scope name", :aggregate_failures do
      folder = create(:folder, collection: run.collection, name: "Auth")

      expect(run.option(:delay_ms)).to eq(0)
      expect(run.scope_name).to eq(run.collection.name)
      run.folder = folder
      expect(run.scope_name).to eq("Auth")
    end

    it "measures its duration", :aggregate_failures do
      expect(run.duration).to be_nil
      expect(create(:collection_run, :completed).duration).to be_within(1).of(60)
      expect(create(:collection_run, :running).duration).to be > 0
    end
  end

  describe "settings" do
    it "reads the limits from the environment with sane bounds", :aggregate_failures do
      expect(described_class.max_requests).to eq(200)
      expect(described_class.retention_days).to eq(30)

      stub_const("ENV", ENV.to_h.merge("SHANGO_RUN_MAX_REQUESTS" => "5000", "SHANGO_RUN_RETENTION_DAYS" => "7"))
      expect(described_class.max_requests).to eq(1_000)
      expect(described_class.retention_days).to eq(7)
    end
  end

  describe "scopes" do
    it "separates active, recent and finished runs", :aggregate_failures do
      queued = create(:collection_run)
      old = create(:collection_run, :completed, finished_at: 40.days.ago)
      fresh = create(:collection_run, :completed)

      expect(described_class.active).to contain_exactly(queued)
      expect(described_class.finished_before(30.days.ago)).to contain_exactly(old)
      expect(described_class.recent.first).to eq(fresh)
    end
  end
end
