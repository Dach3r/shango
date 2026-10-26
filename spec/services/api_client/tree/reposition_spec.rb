require "rails_helper"

RSpec.describe ApiClient::Tree::Reposition do
  let(:project) { create(:project) }
  let!(:first) { create(:collection, project:) }
  let!(:second) { create(:collection, project:) }
  let!(:third) { create(:collection, project:) }

  def positions
    project.collections.ordered.map(&:id)
  end

  it "places the record before the given sibling" do
    described_class.call(record: third, siblings: project.collections, before_id: first.id)

    expect(positions).to eq([third.id, first.id, second.id])
  end

  it "places the record last without before_id" do
    described_class.call(record: first, siblings: project.collections)

    expect(positions).to eq([second.id, third.id, first.id])
  end

  it "places the record last when before_id is unknown" do
    described_class.call(record: first, siblings: project.collections, before_id: SecureRandom.uuid)

    expect(positions).to eq([second.id, third.id, first.id])
  end

  it "only updates positions that changed" do
    described_class.call(record: third, siblings: project.collections)

    expect(positions).to eq([first.id, second.id, third.id])
  end
end
