require "rails_helper"

RSpec.describe ApiClient::Requests::Automation do
  let(:collection) { create(:collection) }
  let(:outer) { create(:folder, collection:) }
  let(:inner) { create(:folder, collection:, parent: outer) }
  let(:api_request) { create(:api_request, collection:, folder: inner) }

  def rule(url)
    { source: "body", operator: "contains", expected: url }
  end

  it "puts the collection first, then the folders from the outermost, then the request", :aggregate_failures do
    collection.update!(assertions: [rule("collection")], extractors: [{ source: "status", variable: "c" }])
    outer.update!(assertions: [rule("outer")])
    inner.update!(assertions: [rule("inner")], extractors: [{ source: "status", variable: "i" }])
    api_request.update!(assertions: [rule("request")], extractors: [{ source: "status", variable: "r" }])

    rules = described_class.call(api_request:).record

    expect(rules[:assertions].pluck("expected")).to eq(%w[collection outer inner request])
    expect(rules[:extractors].pluck("variable")).to eq(%w[c i r])
  end

  it "works for a request outside any folder and for a draft", :aggregate_failures do
    collection.update!(assertions: [rule("collection")])
    loose = create(:api_request, collection:)
    draft = ApiRequest.new(project: collection.project, name: "Draft")

    expect(described_class.call(api_request: loose).record[:assertions].size).to eq(1)
    expect(described_class.call(api_request: draft).record).to eq({ assertions: [], extractors: [] })
  end
end
