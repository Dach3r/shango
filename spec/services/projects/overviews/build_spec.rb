require "rails_helper"

RSpec.describe Projects::Overviews::Build do
  let(:project) { create(:project) }
  let(:user) { create(:user) }

  def build(**)
    described_class.call(project:, user:, **).data
  end

  it "is empty for a project with nothing in it", :aggregate_failures do
    data = build

    expect(data).to include(empty: true, incidents: [], activity: [], runs: [], counts: { requests: 0, monitors: 0, environments: 0 })
    expect(data[:summary]).to include(total: 0, down: 0)
  end

  it "is not empty once the project holds anything", :aggregate_failures do
    create(:collection, project:)
    expect(build[:empty]).to be(false)
  end

  it "is not empty with only a network check" do
    create(:network_check, project:, user:)

    expect(build[:empty]).to be(false)
  end

  it "counts what the project holds", :aggregate_failures do
    create(:api_request, collection: create(:collection, project:))
    create(:uptime_monitor, project:)
    create(:environment, project:)

    expect(build[:counts]).to eq(requests: 1, monitors: 1, environments: 1)
  end

  it "keeps the newest of the member's own runs, whatever their kind", :aggregate_failures do
    api_request = create(:api_request, collection: create(:collection, project:))
    old = create(:request_execution, api_request:, project:, user:, created_at: 3.hours.ago)
    check = create(:network_check, project:, user:, created_at: 2.hours.ago)
    latest = create(:request_execution, api_request:, project:, user:, created_at: 1.hour.ago)
    create(:network_check, project:, user: create(:user))

    expect(build[:runs]).to eq([latest, check, old])
  end

  it "limits every list" do
    6.times { create(:network_check, project:, user:) }

    expect(build[:runs].size).to eq(described_class::LIMIT)
  end

  it "narrows the monitors to an environment and those without one", :aggregate_failures do
    production = create(:environment, project:)
    inside = create(:uptime_monitor, project:, environment: production)
    loose = create(:uptime_monitor, :push, project:)
    outside = create(:uptime_monitor, project:, environment: create(:environment, project:))
    [inside, loose, outside].each { |monitor| create(:incident, uptime_monitor: monitor) }

    expect(build(environment: production)[:incidents].map(&:uptime_monitor)).to contain_exactly(inside, loose)
    expect(build[:incidents].size).to eq(3)
    expect(build(environment: production)[:summary][:total]).to eq(2)
  end
end
