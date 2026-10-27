require "rails_helper"

RSpec.describe Shango::Storage do
  def env(values)
    stub_const("ENV", ENV.to_h.merge(values))
  end

  describe ".service" do
    it "is local by default" do
      expect(described_class.service).to eq(:local)
    end

    it "selects s3" do
      env("SHANGO_STORAGE" => "s3")

      expect(described_class.service).to eq(:s3)
    end

    it "rejects unknown services" do
      env("SHANGO_STORAGE" => "ftp")

      expect { described_class.service }.to raise_error(ArgumentError, /must be one of local, s3/)
    end
  end

  describe "storage.yml" do
    def configs
      ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/storage.yml")).deep_symbolize_keys
    end

    def service(name)
      ActiveStorage::Service.configure(name, configs)
    end

    it "builds the S3 service from the environment", :aggregate_failures do
      env("SHANGO_S3_BUCKET" => "shango-files", "SHANGO_S3_REGION" => "eu-west-1", "SHANGO_S3_ACCESS_KEY_ID" => "key", "SHANGO_S3_SECRET_ACCESS_KEY" => "secret", "SHANGO_S3_ENDPOINT" => "https://minio.example.com")

      expect(service(:s3)).to be_a(ActiveStorage::Service::S3Service)
      expect(service(:s3).bucket.name).to eq("shango-files")
      expect(service(:s3).client.client.config.region).to eq("eu-west-1")
    end

    it "leaves credentials to the AWS SDK chain when none are given", :aggregate_failures do
      env("SHANGO_S3_BUCKET" => "shango-files")

      expect(configs[:s3]).to include(service: "S3", bucket: "shango-files", region: "us-east-1")
      expect(configs[:s3].keys).not_to include(:access_key_id, :endpoint)
    end
  end
end
