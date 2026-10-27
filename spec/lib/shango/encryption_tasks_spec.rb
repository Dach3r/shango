require "rails_helper"
require "rake"

RSpec.describe "shango:encryption tasks" do
  def provider(*keys)
    ActiveRecord::Encryption::DerivedSecretKeyProvider.new(keys)
  end

  def with_keys(*keys, &)
    ActiveRecord::Encryption.with_encryption_context(key_provider: provider(*keys), &)
  end

  before(:all) { Rails.application.load_tasks if Rake::Task.tasks.none? { |task| task.name == "shango:encryption:rotate" } }

  describe "shango:encryption:rotate" do
    it "re-encrypts stored secrets with the newest key", :aggregate_failures do
      environment = create(:environment)
      variable = with_keys("old-key") { Variable.create!(environment:, key: "TOKEN", value: "s3cret", secret: true) }
      collection = with_keys("old-key") { create(:collection, auth_type: "bearer", auth_config: { "token" => "abc" }) }
      Rake::Task["shango:encryption:rotate"].reenable

      expect { with_keys("old-key", "new-key") { Rake::Task["shango:encryption:rotate"].invoke } }.to output(/Re-encrypted \d+ records/).to_stdout

      with_keys("new-key") do
        expect(variable.reload.value).to eq("s3cret")
        expect(collection.reload.auth_config).to eq("token" => "abc")
      end
      expect { with_keys("old-key") { variable.reload.value } }.to raise_error(ActiveRecord::Encryption::Errors::Decryption)
    end
  end

  describe "shango:encryption:derived_keys" do
    it "prints the three variables to pin" do
      Rake::Task["shango:encryption:derived_keys"].reenable

      expect { Rake::Task["shango:encryption:derived_keys"].invoke }.to output(/PRIMARY_KEY=\h{64}\nACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=\h{64}\nACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=\h{64}/).to_stdout
    end
  end
end
