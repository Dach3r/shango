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

  describe "edge cases" do
    it "ignores a before_id equal to the record itself" do
      described_class.call(record: second, siblings: project.collections, before_id: second.id)

      expect(positions).to eq([first.id, third.id, second.id])
    end

    it "treats a blank before_id as last" do
      described_class.call(record: first, siblings: project.collections, before_id: "")

      expect(positions).to eq([second.id, third.id, first.id])
    end

    it "renumbers gaps and duplicate positions contiguously", :aggregate_failures do
      first.update_column(:position, 0)
      second.update_column(:position, 0)
      third.update_column(:position, 50)
      described_class.call(record: third, siblings: project.collections, before_id: first.id)

      expect(project.collections.ordered.pluck(:position)).to eq([1, 2, 3])
    end

    it "does not touch records outside the sibling scope", :aggregate_failures do
      outsider = create(:collection)
      outsider.update_column(:position, 7)
      described_class.call(record: first, siblings: project.collections)

      expect(outsider.reload.position).to eq(7)
    end

    it "works with a lone record" do
      lone = create(:collection)
      described_class.call(record: lone, siblings: lone.project.collections, before_id: first.id)

      expect(lone.reload.position).to eq(1)
    end
  end
end
