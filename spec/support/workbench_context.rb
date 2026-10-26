RSpec.shared_context "with workbench project" do
  let!(:session_context) { sign_in_with_project }
  let(:user) { session_context[0] }
  let(:project) { session_context[1] }
  let(:membership) { session_context[2] }
  let(:collection) { create(:collection, project:) }
  let(:folder) { create(:folder, collection:) }
  let(:api_request) { create(:api_request, collection:) }
  let(:foreign_collection) { create(:collection) }
  let(:foreign_folder) { create(:folder, collection: foreign_collection) }
  let(:foreign_request) { create(:api_request, collection: foreign_collection) }
  let(:turbo_headers) { { "Accept" => "text/vnd.turbo-stream.html, text/html" } }
end
