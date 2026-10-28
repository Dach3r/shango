require "rails_helper"

RSpec.describe CollectionExport do
  it "is active while it is queued or running and has not expired", :aggregate_failures do
    expect(build(:collection_export)).to be_active
    expect(build(:collection_export, status: "running")).to be_active
    expect(build(:collection_export, status: "done")).not_to be_active
    expect(build(:collection_export, expires_at: 1.minute.ago)).not_to be_active
  end

  it "can be downloaded once done and until it expires", :aggregate_failures do
    expect(build(:collection_export, :done)).to be_downloadable
    expect(build(:collection_export, :done, expires_at: 1.minute.ago)).not_to be_downloadable
    expect(build(:collection_export)).not_to be_downloadable
    expect(build(:collection_export, :done, expires_at: 1.minute.ago)).to be_expired
  end

  it "decodes the stored file" do
    expect(build(:collection_export, :done).file_content).to eq('{"ok":true}')
  end

  it "keeps the file encrypted at rest" do
    export = create(:collection_export, :done)

    expect(CollectionExport.connection.select_value("SELECT content FROM collection_exports WHERE id = '#{export.id}'")).not_to include(Base64.strict_encode64('{"ok":true}'))
  end

  describe ".retention" do
    it "is an hour by default and honors SHANGO_EXPORT_RETENTION_MINUTES within limits", :aggregate_failures do
      expect(described_class.retention).to eq(60.minutes)

      stub_const("ENV", ENV.to_h.merge("SHANGO_EXPORT_RETENTION_MINUTES" => "5"))
      expect(described_class.retention).to eq(5.minutes)

      stub_const("ENV", ENV.to_h.merge("SHANGO_EXPORT_RETENTION_MINUTES" => "0"))
      expect(described_class.retention).to eq(1.minute)
    end
  end

  it "lists expired exports" do
    old = create(:collection_export, expires_at: 1.minute.ago)
    create(:collection_export)

    expect(described_class.expired).to contain_exactly(old)
  end
end
