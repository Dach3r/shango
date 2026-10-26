require "rails_helper"

RSpec.describe Environment do
  subject(:environment) { create(:environment) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_uniqueness_of(:name).scoped_to(:project_id).case_insensitive }

  describe "positioning" do
    it "appends to the project's environments", :aggregate_failures do
      first = create(:environment, project: environment.project)

      expect(environment.position).to eq(1)
      expect(first.position).to eq(2)
    end

    it "keeps an explicit position" do
      expect(create(:environment, position: 5).position).to eq(5)
    end
  end

  describe "nested variables" do
    it "ignores blank rows", :aggregate_failures do
      environment.update!(variables_attributes: [{ key: "", value: "" }, { key: "HOST", value: "x" }])

      expect(environment.variables.map(&:key)).to eq(["HOST"])
    end
  end

  describe "#variable_values" do
    it "maps enabled variables to string values", :aggregate_failures do
      create(:variable, environment:, key: "A", value: "1")
      create(:variable, environment:, key: "B", value: "2", enabled: false)
      create(:variable, environment:, key: "C", value: nil)

      expect(environment.reload.variable_values).to eq("A" => "1", "C" => "")
    end
  end

  describe "#secret_values" do
    it "returns enabled non-blank secret values", :aggregate_failures do
      create(:variable, :secret, environment:, key: "S1", value: "s3cret")
      create(:variable, :secret, environment:, key: "S2", value: "off", enabled: false)
      create(:variable, :secret, environment:, key: "S3", value: nil)
      create(:variable, environment:, key: "P", value: "public")

      expect(environment.reload.secret_values).to eq(["s3cret"])
    end
  end

  describe "dependents" do
    it "nullifies membership selection on destroy" do
      membership = create(:membership, project: environment.project, current_environment: environment)

      environment.destroy

      expect(membership.reload.current_environment).to be_nil
    end
  end
end
