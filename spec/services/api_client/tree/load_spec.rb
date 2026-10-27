require "rails_helper"

RSpec.describe ApiClient::Tree::Load do
  let(:project) { create(:project) }
  let(:collection) { create(:collection, project:) }
  let(:folder) { create(:folder, collection:) }
  let(:child) { create(:folder, collection:, parent: folder) }
  let(:root_request) { create(:api_request, collection:) }
  let(:nested_request) { create(:api_request, collection:, folder:) }

  it "groups folders and requests per collection", :aggregate_failures do
    [child, root_request, nested_request]
    empty = create(:collection, project:)

    branches = described_class.call(project:)
    branch = branches.find { |candidate| candidate.collection == collection }

    expect(branches.map(&:collection)).to eq([collection, empty])
    expect(branch.root_folders).to eq([folder])
    expect(branch.children_of(folder)).to eq([child])
    expect(branch.children_of(child)).to eq([])
    expect(branch.requests_in).to eq([root_request])
    expect(branch.requests_in(folder)).to eq([nested_request])
    expect(branches.last.root_folders).to eq([])
  end

  it "looks up folders and the path to a folder inside a branch", :aggregate_failures do
    [child, root_request, nested_request]
    branch = described_class.call(project:).first

    expect(branch.all_requests).to contain_exactly(root_request, nested_request)
    expect(branch.folder(child.id)).to eq(child)
    expect(branch.folder(nil)).to be_nil
    expect(branch.folder_path(child.id)).to eq([folder, child])
    expect(branch.folder_path(nil)).to eq([])
  end

  it "stops walking a folder path that loops back on itself" do
    loop_folder = create(:folder, collection:)
    loop_folder.update_column(:parent_id, loop_folder.id)

    expect(described_class.call(project:).first.folder_path(loop_folder.id)).to eq([loop_folder])
  end

  it "does not load folder credentials" do
    folder

    expect(described_class.call(project:).first.root_folders.first.attributes.keys).not_to include("auth_config")
  end

  it "runs a fixed number of queries however big the project is", :aggregate_failures do
    described_class.call(project:)
    baseline = count_queries { described_class.call(project:).each { |branch| branch.requests_in } }
    3.times do
      branch_collection = create(:collection, project:)
      branch_folder = create(:folder, collection: branch_collection)
      create_list(:api_request, 3, collection: branch_collection, folder: branch_folder, project:)
    end

    expect(baseline).to be <= 3
    expect(count_queries { described_class.call(project:).each { |branch| branch.requests_in } }).to eq(baseline)
  end

  it "ignores other projects" do
    create(:collection)

    expect(described_class.call(project:)).to eq([])
  end
end
