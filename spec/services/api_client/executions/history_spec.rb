require "rails_helper"

RSpec.describe ApiClient::Executions::History do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let!(:first) { create(:collection, project:) }
  let!(:second) { create(:collection, project:) }

  def execution_for(api_request, **attributes)
    create(:request_execution, api_request:, user:, **attributes)
  end

  it "groups executions by collection, newest first, with drafts last", :aggregate_failures do
    draft = create(:api_request, project:, collection: nil, user:)
    older = execution_for(create(:api_request, project:, collection: second), created_at: 2.days.ago)
    newer = execution_for(create(:api_request, project:, collection: second), created_at: 1.day.ago)
    in_first = execution_for(create(:api_request, project:, collection: first))
    drafted = execution_for(draft)
    create(:collection, project:)

    groups = described_class.call(project:, user:)

    expect(groups.map(&:collection)).to eq([first, second, nil])
    expect(groups.map { |group| group.executions.map(&:id) }).to eq([[in_first.id], [newer.id, older.id], [drafted.id]])
  end

  it "skips groups without executions" do
    create(:api_request, project:, collection: first)

    expect(described_class.call(project:, user:)).to eq([])
  end

  it "ignores other users, other projects and other users' drafts", :aggregate_failures do
    shared = create(:api_request, project:, collection: first)
    create(:request_execution, api_request: shared, user: create(:user))
    foreign = create(:api_request)
    create(:request_execution, api_request: foreign, user:, project: foreign.project)
    create(:request_execution, api_request: create(:api_request, project:, collection: nil, user: create(:user)), user:)

    expect(described_class.call(project:, user:)).to eq([])
  end
end
