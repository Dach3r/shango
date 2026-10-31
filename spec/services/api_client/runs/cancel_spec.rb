require "rails_helper"

RSpec.describe ApiClient::Runs::Cancel do
  let(:run) { create(:collection_run) }

  before do
    create(:collection_run_item, collection_run: run)
    create(:collection_run_item, collection_run: run)
  end

  it "cancels the run and skips what was waiting", :aggregate_failures do
    expect(described_class.call(run:)).to be_success
    expect(run.reload).to be_cancelled
    expect(run.items.map(&:status)).to eq(%w[skipped skipped])
  end

  it "skips the request in flight too" do
    run.items.first.start!

    described_class.call(run:)

    expect(run.items.reload.map(&:status)).to eq(%w[skipped skipped])
  end

  it "leaves the finished items alone", :aggregate_failures do
    first = run.items.first
    first.start!
    first.mark_passed!

    described_class.call(run:)

    expect(run.items.reload.map(&:status)).to eq(%w[passed skipped])
  end

  it "tells the open run page to refresh" do
    allow(Turbo::StreamsChannel).to receive(:broadcast_refresh_to)

    described_class.call(run:)

    expect(Turbo::StreamsChannel).to have_received(:broadcast_refresh_to).with(run)
  end

  it "has nothing to cancel in a finished run", :aggregate_failures do
    done = create(:collection_run, :completed)

    expect(described_class.call(run: done)).to be_failure
    expect(done.reload).to be_completed
  end
end
