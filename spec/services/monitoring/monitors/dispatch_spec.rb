require "rails_helper"

RSpec.describe Monitoring::Monitors::Dispatch do
  include ActiveJob::TestHelper

  let(:now) { Time.zone.parse("2026-10-29 10:00:00") }

  def monitor(next_check_at:, **attributes)
    create(:uptime_monitor, next_check_at:, **attributes)
  end

  it "enqueues the due monitors and moves them one interval forward from their planned time", :aggregate_failures do
    due = monitor(next_check_at: now - 20.seconds, interval: 300)
    early = monitor(next_check_at: now + 3.seconds, interval: 60)
    later = monitor(next_check_at: now + 1.minute)
    paused = monitor(next_check_at: now - 1.minute, enabled: false)

    result = described_class.call(now:)

    expect(result.data).to eq(dispatched: 2)
    expect(due.reload.next_check_at).to eq(now - 20.seconds + 300.seconds)
    expect(early.reload.next_check_at).to eq(now + 63.seconds)
    expect([later.reload.next_check_at, paused.reload.next_check_at]).to eq([now + 1.minute, now - 1.minute])
    expect(MonitorCheckJob).to have_been_enqueued.with(due.id, due.config_version)
    expect(MonitorCheckJob).to have_been_enqueued.with(early.id, early.config_version)
    expect(enqueued_jobs.size).to eq(2)
  end

  it "restarts from now when more than one interval was missed" do
    missed = monitor(next_check_at: now - 2.hours, interval: 300)
    described_class.call(now:)

    expect(missed.reload.next_check_at).to eq(now + 300.seconds)
  end

  it "takes at most one batch per run" do
    stub_const("#{described_class}::BATCH", 1)
    2.times { |index| monitor(next_check_at: now - index.minutes) }

    expect(described_class.call(now:).data).to eq(dispatched: 1)
  end

  it "skips monitors without a planned check" do
    monitor(next_check_at: nil)

    expect(described_class.call(now:).data).to eq(dispatched: 0)
  end
end
