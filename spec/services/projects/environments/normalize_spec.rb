require "rails_helper"

RSpec.describe Projects::Environments::Normalize do
  it "returns attributes unchanged without variable rows", :aggregate_failures do
    expect(described_class.call(attributes: { name: "A" })).to eq("name" => "A")
    expect(described_class.call(attributes: { name: "A", variables_attributes: [] })).to include("name" => "A")
  end

  it "positions array rows" do
    result = described_class.call(attributes: { variables_attributes: [{ key: "a" }, { key: "b" }] })

    expect(result[:variables_attributes].pluck(:position)).to eq([0, 1])
  end

  it "positions hash rows keyed by form index" do
    result = described_class.call(attributes: { variables_attributes: { "0" => { key: "a" }, "1" => { key: "b" } } })

    expect(result[:variables_attributes].map { |row| row.slice(:key, :position) }).to eq([{ "key" => "a", "position" => 0 }, { "key" => "b", "position" => 1 }])
  end

  it "accepts ActionController::Parameters" do
    params = ActionController::Parameters.new(name: "A").permit(:name)

    expect(described_class.call(attributes: params)).to eq("name" => "A")
  end
end
