require "rails_helper"

RSpec.describe "Database indexes" do
  let(:connection) { ActiveRecord::Base.connection }

  it "indexes the saved-response history lookup" do
    expect(connection.index_exists?(:request_executions, %i[project_id user_id created_at])).to be(true)
  end

  it "indexes the sidebar tree order" do
    expect(connection.index_exists?(:api_requests, %i[project_id collection_id folder_id position])).to be(true)
  end

  it "indexes drafts per user as a partial index", :aggregate_failures do
    index = connection.indexes(:api_requests).find { |candidate| candidate.name == "index_api_requests_on_drafts" }

    expect(index.columns).to eq(%w[project_id user_id])
    expect(index.where).to eq("(collection_id IS NULL)")
  end
end
