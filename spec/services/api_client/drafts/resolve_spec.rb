require "rails_helper"

RSpec.describe ApiClient::Drafts::Resolve do
  let(:project) { create(:project) }
  let(:user) { create(:user) }

  it "finds a saved request of the project" do
    saved = create(:api_request, collection: create(:collection, project:))

    expect(described_class.call(project:, user:, id: saved.id)).to eq(saved)
  end

  it "rebuilds the user's new draft in memory", :aggregate_failures do
    draft = create(:request_draft, project:, user:)
    request = described_class.call(project:, user:, id: draft.id)

    expect(request).to be_new_record
    expect(request.id).to eq(draft.id)
  end

  it "finds a saved request without a project, for the workers" do
    saved = create(:api_request)

    expect(described_class.call(user:, id: saved.id)).to eq(saved)
  end

  it "finds the user's draft without a project, for the workers" do
    draft = create(:request_draft, user:)

    expect(described_class.call(user:, id: draft.id).id).to eq(draft.id)
  end

  it "does not find saved requests of other projects" do
    expect { described_class.call(project:, user:, id: create(:api_request).id) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "does not find drafts of other users or projects", :aggregate_failures do
    expect { described_class.call(project:, user:, id: create(:request_draft, project:).id) }.to raise_error(ActiveRecord::RecordNotFound)
    expect { described_class.call(project:, user:, id: create(:request_draft, user:).id) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "does not treat the pending edits of a saved request as a draft" do
    edits = create(:request_draft, :for_request, project:, user:)

    expect { described_class.call(project:, user:, id: edits.id) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "raises for an unknown id" do
    expect { described_class.call(project:, user:, id: SecureRandom.uuid) }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
