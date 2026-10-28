require "rails_helper"
require "open3"

RSpec.describe ApiClient::Exports::Zip do
  it "builds an archive that standard tools can read", :aggregate_failures do
    archive = Rails.root.join("tmp/zip_spec.zip")
    File.binwrite(archive, described_class.build("a.json" => '{"a":1}', "ñ/b.txt" => "hola"))
    listing, status = Open3.capture2("unzip", "-l", archive.to_s)
    content, = Open3.capture2("unzip", "-p", archive.to_s, "a.json")

    expect(status).to be_success
    expect(listing).to include("a.json").and include("b.txt")
    expect(content).to eq('{"a":1}')
  ensure
    FileUtils.rm_f(archive)
  end
end
