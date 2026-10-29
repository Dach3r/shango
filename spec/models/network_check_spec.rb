require "rails_helper"

RSpec.describe NetworkCheck do
  it "requires a target" do
    expect(build(:network_check, target: "")).not_to be_valid
  end

  it "keeps the kind and outcome as strings with a database check", :aggregate_failures do
    expect(create(:network_check, :ports)).to be_ports
    expect(described_class.kinds.values).to eq(%w[dns ports ping subnet])
    expect(create(:network_check, :subnet)).to be_subnet
    expect { create(:network_check).update_columns(kind: "icmp") }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "orders the newest first" do
    old = create(:network_check, created_at: 2.days.ago)
    recent = create(:network_check, created_at: 1.day.ago)

    expect(described_class.recent).to eq([recent, old])
  end

  it "turns the stored result back into the objects the views read", :aggregate_failures do
    data = create(:network_check).data

    expect(data[:rows].first).to be_a(Network::Dns::Row)
    expect(data[:rows].first.status).to eq(:ok)
    expect(data[:summary]).to include(total: 1)
  end

  it "summarizes the run" do
    expect(create(:network_check).digest.label).to eq("example.com · A")
  end

  describe "#previous" do
    let(:project) { create(:project) }

    it "is the run before this one against the same target and tool", :aggregate_failures do
      first = create(:network_check, project:, created_at: 3.hours.ago)
      create(:network_check, project:, target: "other.com", created_at: 2.hours.ago)
      create(:network_check, :ports, project:, created_at: 2.hours.ago)
      second = create(:network_check, project:, created_at: 1.hour.ago)

      expect(second.previous).to eq(first)
      expect(first.previous).to be_nil
    end

    it "ignores other users" do
      create(:network_check, project:, created_at: 3.hours.ago)

      expect(create(:network_check, project:, user: create(:user), created_at: 1.hour.ago).previous).to be_nil
    end

    it "ignores other projects" do
      create(:network_check, created_at: 3.hours.ago)

      expect(create(:network_check, project:, created_at: 1.hour.ago).previous).to be_nil
    end
  end
end
