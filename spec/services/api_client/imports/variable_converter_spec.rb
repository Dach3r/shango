require "rails_helper"

RSpec.describe ApiClient::Imports::VariableConverter do
  let(:warnings) { [] }

  describe ".call" do
    it "returns non-strings and plain text untouched", :aggregate_failures do
      expect(described_class.call(nil, warnings)).to be_nil
      expect(described_class.call("plain", warnings)).to eq("plain")
    end

    it "rewrites Insomnia, Postman dynamic and spaced references", :aggregate_failures do
      expect(described_class.call("{{ _.host }}/{{$randomUUID}}/{{ id }}/{{$timestamp}}", warnings)).to eq("{{host}}/{{$guid}}/{{id}}/{{$timestamp}}")
      expect(warnings).to be_empty
    end

    it "reports unsupported helpers once and keeps them", :aggregate_failures do
      expect(described_class.call("{{$randomEmail}} {{$randomEmail}}", warnings)).to eq("{{$randomEmail}} {{$randomEmail}}")
      expect(warnings).to eq([I18n.t("workbench.imports.warnings.variable_unsupported", name: "$randomEmail")])
    end
  end

  describe ".request" do
    it "converts every text field of a request" do
      attributes = ApiClient::Imports::Support.request(
        name: "r", url: "{{ _.base }}", headers: [ApiClient::Imports::Support.row("X", "{{ _.a }}")], body: "{{ _.b }}",
        auth_config: { "token" => "{{ _.t }}" }
      )
      result = described_class.request(attributes, warnings)
      expect(result).to include(url: "{{base}}", body: "{{b}}", auth_config: { "token" => "{{t}}" })
      expect(result[:headers].first["value"]).to eq("{{a}}")
    end
  end
end
