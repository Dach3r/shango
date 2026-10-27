require "rails_helper"

RSpec.describe Network::Checks::Record do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:environment) { create(:environment, project:) }
  let(:result) do
    row = Network::PortChecks::Row.new(port: 22, service: "ssh", status: :open, ms: 7)
    Result.success(nil, host: "example.com", address: "203.0.113.9", rows: [row], counts: { open: 1, closed: 0, filtered: 0 })
  end

  def record(**options)
    described_class.call(kind: :ports, result:, input: { host: "{{host}}", ports: "22" }, project:, user:, environment:, **options)
  end

  it "saves the run with what was typed, not what it resolved to", :aggregate_failures do
    check = record.record

    expect(check).to have_attributes(project:, user:, environment:, kind: "ports", target: "example.com", outcome: "ok")
    expect(check.input).to eq("host" => "{{host}}", "ports" => "22")
    expect(check.data[:rows].first.port).to eq(22)
  end

  it "cuts long input" do
    check = record(input: { host: "a" * 1000 }).record

    expect(check.input["host"].length).to eq(NetworkCheck::INPUT_LIMIT)
  end

  it "does not record failed runs", :aggregate_failures do
    outcome = record(result: Result.failure(error: :invalid))

    expect(outcome).to be_failure
    expect(NetworkCheck.count).to eq(0)
  end

  it "keeps the newest runs of each tool and leaves the others alone", :aggregate_failures do
    stub_const("NetworkCheck::KEEP_PER_KIND", 2)
    old = create(:network_check, :ports, project:, user:, created_at: 3.days.ago)
    middle = create(:network_check, :ports, project:, user:, created_at: 2.days.ago)
    dns = create(:network_check, project:, user:, created_at: 4.days.ago)
    other_project = create(:network_check, :ports, created_at: 5.days.ago)
    teammate = create(:network_check, :ports, project:, created_at: 6.days.ago)
    check = record.record

    expect(NetworkCheck.ports.where(project:, user:)).to contain_exactly(middle, check)
    expect(NetworkCheck.exists?(old.id)).to be(false)
    expect(NetworkCheck.where(id: [dns.id, other_project.id, teammate.id]).count).to eq(3)
  end

  it "does not break the run when the history cannot be saved", :aggregate_failures do
    allow(Rails.logger).to receive(:warn)
    allow(project).to receive(:network_checks).and_return(instance_double(ActiveRecord::Associations::CollectionProxy).tap { |scope| allow(scope).to receive(:create!).and_raise(ActiveRecord::RecordInvalid) })
    outcome = record

    expect(outcome).to be_failure
    expect(Rails.logger).to have_received(:warn).with(/history not saved/)
  end
end
