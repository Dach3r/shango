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

    it "resolves chains up to the depth limit and reports what is left", :aggregate_failures do
      chain = described_class.new({ "v1" => "{{v2}}", "v2" => "{{v3}}", "v3" => "{{v4}}", "v4" => "{{v5}}", "v5" => "{{v6}}", "v6" => "{{v7}}", "v7" => "end" })

      expect(chain.resolve("{{v1}}")).to eq("{{v6}}")
      expect(chain.unresolved.to_a).to eq(["v6"])
    end

    it "stops on self references", :aggregate_failures do
      resolver = described_class.new({ "a" => "x{{a}}" })

      expect(resolver.resolve("{{a}}")).to eq("xxxxx{{a}}")
      expect(resolver.unresolved.to_a).to eq(["a"])
    end

    it "inserts values literally, even with regexp backreferences and backslashes", :aggregate_failures do
      resolver = described_class.new({ "a" => "\\1 \\0 \\& $1 \\\\" })

      expect(resolver.resolve("<{{a}}>")).to eq("<\\1 \\0 \\& $1 \\\\>")
    end

    it "inserts empty values", :aggregate_failures do
      resolver = described_class.new({ "empty" => "" })

      expect(resolver.resolve("a{{empty}}b")).to eq("ab")
      expect(resolver.unresolved).to be_empty
    end

    it "treats a nil value as undefined" do
      resolver = described_class.new({ "a" => nil })

      expect(resolver.resolve("{{a}}")).to eq("{{a}}")
    end

    it "ignores malformed tokens", :aggregate_failures do
      resolver = described_class.new({ "a" => "x" })

      expect(resolver.resolve("{{}} {{ }} {a} {{a}")).to eq("{{}} {{ }} {a} {{a}")
      expect(resolver.unresolved).to be_empty
    end

    it "resolves the inner braces of triple braces" do
      expect(described_class.new({ "a" => "x" }).resolve("{{{a}}}")).to eq("{x}")
    end

    it "resolves names with dots, dashes and unicode", :aggregate_failures do
      resolver = described_class.new({ "user.name" => "ann", "api-key" => "k", "clé" => "v" })

      expect(resolver.resolve("{{user.name}} {{api-key}} {{clé}}")).to eq("ann k v")
    end

    it "is case sensitive" do
      resolver = described_class.new({ "Host" => "a" })

      expect(resolver.resolve("{{host}}")).to eq("{{host}}")
    end

    it "lets variables shadow dynamic helpers", :aggregate_failures do
      resolver = described_class.new({ "$guid" => "fixed" })

      expect(resolver.resolve("{{$guid}}")).to eq("fixed")
    end

    it "reports each unresolved name once", :aggregate_failures do
      resolver.resolve("{{x}} {{x}}")
      resolver.resolve("{{x}}")

      expect(resolver.unresolved.to_a).to eq(["x"])
    end

    it "generates a new dynamic value on every occurrence" do
      guids = resolver.resolve("{{$guid}} {{$guid}}").split

      expect(guids.uniq.size).to eq(2)
    end

    it "does not evaluate the helper output again" do
      allow(SecureRandom).to receive(:uuid).and_return("{{host}}")

      expect(resolver.resolve("{{$guid}}")).to eq("api.test")
    end

    it "handles multiline and very long text", :aggregate_failures do
      expect(resolver.resolve("a\n{{host}}\nb")).to eq("a\napi.test\nb")
      expect(resolver.resolve("{{host}}" * 2000)).to eq("api.test" * 2000)
    end
  end

  describe "#resolve_deep" do
    it "walks strings, arrays and hashes" do
      result = resolver.resolve_deep({ "a" => ["{{host}}", 1], "b" => { "c" => "{{host}}" } })

      expect(result).to eq({ "a" => ["api.test", 1], "b" => { "c" => "api.test" } })
    end

    it "leaves other objects and hash keys alone", :aggregate_failures do
      expect(resolver.resolve_deep({ "{{host}}" => nil, "n" => 1.5, "t" => true })).to eq({ "{{host}}" => nil, "n" => 1.5, "t" => true })
      expect(resolver.resolve_deep(nil)).to be_nil
    end
  end
end
