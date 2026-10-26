require "rails_helper"

RSpec.describe ApiClient::VariableResolver do
  subject(:resolver) { described_class.new(values) }

  let(:values) { { host: "api.test", "path" => "{{host}}/v1", "loop_a" => "{{loop_b}}", "loop_b" => "{{loop_a}}" } }

  describe "#resolve" do
    it "replaces known variables", :aggregate_failures do
      expect(resolver.resolve("https://{{ host }}/x")).to eq("https://api.test/x")
      expect(resolver.unresolved).to be_empty
    end

    it "resolves nested references" do
      expect(resolver.resolve("{{path}}")).to eq("api.test/v1")
    end

    it "resolves dynamic helpers", :aggregate_failures do
      expect(resolver.resolve("{{$timestamp}}")).to match(/\A\d+\z/)
      expect(resolver.resolve("{{$isoTimestamp}}")).to match(/\A\d{4}-\d\d-\d\dT/)
      expect(resolver.resolve("{{$guid}}")).to match(/\A\h{8}-/)
      expect(resolver.resolve("{{$randomInt}}")).to match(/\A\d+\z/)
    end

    it "reports unknown names and leaves them", :aggregate_failures do
      expect(resolver.resolve("{{missing}} {{$nope}}")).to eq("{{missing}} {{$nope}}")
      expect(resolver.unresolved.to_a).to contain_exactly("missing", "$nope")
    end

    it "asks the extra lookup for unknown names", :aggregate_failures do
      extra = ->(name) { name == "response.x" ? "from response" : nil }
      resolver = described_class.new(values, extra:)

      expect(resolver.resolve("{{response.x}} {{other}}")).to eq("from response {{other}}")
      expect(resolver.unresolved.to_a).to eq(["other"])
    end

    it "stops on circular references", :aggregate_failures do
      expect(resolver.resolve("{{loop_a}}")).to match(/\{\{loop_[ab]\}\}/)
      expect(resolver.unresolved).not_to be_empty
    end

    it "returns non templates as is", :aggregate_failures do
      expect(resolver.resolve("plain")).to eq("plain")
      expect(resolver.resolve(nil)).to be_nil
      expect(resolver.resolve(5)).to eq(5)
    end
  end

  describe "#resolve_deep" do
    it "walks strings, arrays and hashes" do
      result = resolver.resolve_deep({ "a" => ["{{host}}", 1], "b" => { "c" => "{{host}}" } })

      expect(result).to eq({ "a" => ["api.test", 1], "b" => { "c" => "api.test" } })
    end
  end
end
