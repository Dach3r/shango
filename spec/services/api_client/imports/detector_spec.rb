require "rails_helper"

RSpec.describe ApiClient::Imports::Detector do
  def detect(data)
    described_class.call(data:)
  end

  {
    "openapi 3" => [{ "openapi" => "3.0.0" }, :openapi],
    "swagger 2" => [{ "swagger" => "2.0" }, :openapi],
    "postman collection" => [{ "info" => { "name" => "A" }, "item" => [] }, :postman],
    "postman environment" => [{ "name" => "E", "values" => [] }, :postman_environment],
    "insomnia v4" => [{ "_type" => "export", "resources" => [] }, :insomnia],
    "insomnia v5" => [{ "type" => "collection.insomnia.rest/5.0" }, :insomnia],
    "bruno" => [{ "name" => "B", "items" => [] }, :bruno]
  }.each do |label, (data, format)|
    it "detects #{label}" do
      expect(detect(data).record).to eq(format)
    end
  end

  it "fails for unknown or non-object data", :aggregate_failures do
    expect(detect({ "foo" => 1 })).to be_failure
    expect(detect([1])).to be_failure
    expect(detect(nil).error).to eq(I18n.t("workbench.imports.errors.unknown_format"))
  end
end
