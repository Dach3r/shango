require "rails_helper"

RSpec.describe ApiClient::Scripting::Sandbox do
  let(:request) { { url: "https://a.test/x", http_method: "GET", headers: [{ "key" => "A", "value" => "1", "enabled" => true, "description" => "" }], body: "" } }
  let(:response) { { status: 201, status_text: "Created", headers: [["Content-Type", "application/json"], ["X-Id", "7"]], body: { token: "abc", n: 3, tags: %w[a b] }.to_json, duration_ms: 12 } }
  let(:environment) { { "host" => "h" } }
  let(:variables) { { "local" => "1" } }

  def run(source, phase: :post, response: self.response)
    described_class.call(source:, phase:, environment:, variables:, request:, response:).record
  end

  def test_named(outcome, name)
    outcome.tests.find { |test| test["name"] == name }
  end

  describe "tests and assertions" do
    it "records passes and failures with the reason", :aggregate_failures do
      outcome = run(<<~JS)
        pm.test("passes", () => pm.expect(1).to.equal(1));
        pm.test("fails", () => pm.expect(pm.response.json().n).to.equal(4));
        pm.test("throws", () => { throw new Error("custom"); });
      JS

      expect(outcome.error).to be_nil
      expect(test_named(outcome, "passes")).to include("passed" => true, "message" => nil)
      expect(test_named(outcome, "fails")).to include("passed" => false, "message" => "expected 3 to equal 4")
      expect(test_named(outcome, "throws")).to include("passed" => false, "message" => "custom")
    end

    it "supports the chai-style expectations", :aggregate_failures do
      outcome = run(<<~JS)
        const t = (name, fn) => pm.test(name, fn);
        t("equal", () => pm.expect("a").to.equal("a"));
        t("deep", () => pm.expect({ a: [1, { b: 2 }] }).to.deep.equal({ a: [1, { b: 2 }] }));
        t("eql", () => pm.expect([1, 2]).to.eql([1, 2]));
        t("not", () => pm.expect(1).to.not.equal(2));
        t("include string", () => pm.expect("hello").to.include("ell"));
        t("include array", () => pm.expect([1, 2]).to.include(2));
        t("include object", () => pm.expect({ a: 1, b: 2 }).to.include({ a: 1 }));
        t("property", () => pm.expect({ a: 1 }).to.have.property("a"));
        t("property value", () => pm.expect({ a: 1 }).to.have.property("a", 1));
        t("a", () => pm.expect([]).to.be.an("array"));
        t("above", () => pm.expect(5).to.be.above(3));
        t("below", () => pm.expect(1).to.be.below(3));
        t("least most", () => { pm.expect(3).to.be.at.least(3); pm.expect(3).to.be.at.most(3); });
        t("within", () => pm.expect(5).to.be.within(1, 9));
        t("oneOf", () => pm.expect("b").to.be.oneOf(["a", "b"]));
        t("match", () => pm.expect("abc").to.match(/b/));
        t("lengthOf", () => pm.expect([1, 2]).to.have.lengthOf(2));
        t("length", () => pm.expect("ab").to.have.length(2));
        t("flags", () => { pm.expect(true).to.be.true; pm.expect(false).to.be.false; pm.expect(null).to.be.null; pm.expect(undefined).to.be.undefined; pm.expect(1).to.be.ok; });
        t("exist", () => pm.expect(1).to.exist);
        t("empty", () => { pm.expect([]).to.be.empty; pm.expect("").to.be.empty; pm.expect({}).to.be.empty; });
      JS

      expect(outcome.tests.reject { |test| test["passed"] }).to be_empty
      expect(outcome.tests.size).to eq(21)
    end

    it "fails the expectations that do not hold, with a readable message", :aggregate_failures do
      outcome = run(<<~JS)
        pm.test("1", () => pm.expect(1).to.equal(2));
        pm.test("2", () => pm.expect(1).to.not.equal(1));
        pm.test("3", () => pm.expect({ a: 1 }).to.deep.equal({ a: 2 }));
        pm.test("4", () => pm.expect("abc").to.include("z"));
        pm.test("5", () => pm.expect({}).to.have.property("a"));
        pm.test("6", () => pm.expect(1).to.be.a("string"));
        pm.test("7", () => pm.expect(1).to.be.above(5));
        pm.test("8", () => pm.expect("a").to.be.oneOf(["b"]));
        pm.test("9", () => pm.expect("a").to.match(/b/));
        pm.test("10", () => pm.expect([1]).to.have.lengthOf(3));
        pm.test("11", () => pm.expect(null).to.exist);
        pm.test("12", () => pm.expect([1]).to.be.empty);
        pm.test("13", () => pm.expect(false).to.be.true);
        pm.test("14", () => pm.expect(1).to.be.null);
        pm.test("15", () => pm.expect(1).to.be.undefined);
        pm.test("16", () => pm.expect(0).to.be.ok);
        pm.test("17", () => pm.expect(1).to.be.below(0));
        pm.test("18", () => pm.expect(1).to.be.within(5, 9));
        pm.test("19", () => pm.expect(1).to.be.false);
        pm.test("20", () => pm.expect(1).to.be.at.least(5));
        pm.test("21", () => pm.expect(9).to.be.at.most(5));
        pm.test("22", () => pm.expect({ a: 1 }).to.have.property("a", 2));
        pm.test("23", () => pm.expect(1).to.eql(2));
      JS

      expect(outcome.tests).to all(include("passed" => false))
      expect(outcome.tests.pluck("message")).to all(be_present)
      expect(test_named(outcome, "5")["message"]).to eq('expected {} to have property "a"')
    end

    it "negates expectations" do
      outcome = run(<<~JS)
        pm.test("a", () => pm.expect(1).to.not.be.a("string"));
        pm.test("b", () => pm.expect([1]).to.not.be.empty);
        pm.test("c", () => pm.expect(1).to.not.be.above(5));
        pm.test("d", () => pm.expect(null).to.not.exist);
        pm.test("e", () => pm.expect(1).to.not.be.true);
      JS

      expect(outcome.tests.reject { |test| test["passed"] }).to be_empty
    end

    it "keeps long names and messages short and stops at the limit of tests", :aggregate_failures do
      outcome = run(<<~JS)
        pm.test("x".repeat(500), () => { throw new Error("y".repeat(2000)); });
        for (let i = 0; i < 150; i++) pm.test("t" + i, () => {});
      JS

      expect(outcome.tests.size).to eq(100)
      expect(outcome.tests.first["name"].length).to eq(200)
      expect(outcome.tests.first["message"].length).to eq(500)
    end
  end

  describe "pm.response" do
    it "exposes the status, headers, body and time", :aggregate_failures do
      outcome = run(<<~JS)
        pm.environment.set("code", pm.response.code);
        pm.environment.set("status", pm.response.status);
        pm.environment.set("time", pm.response.responseTime);
        pm.environment.set("id", pm.response.headers.get("x-id"));
        pm.environment.set("has", pm.response.headers.has("X-ID"));
        pm.environment.set("text", pm.response.text().length);
        pm.environment.set("token", pm.response.json().token);
        pm.test("status", () => pm.response.to.have.status(201));
        pm.test("wrong status", () => pm.response.to.have.status(200));
        pm.test("header", () => pm.response.to.have.header("X-Id"));
        pm.test("missing header", () => pm.response.to.have.header("X-Nope"));
      JS

      expect(outcome.env_writes).to include("code" => "201", "status" => "Created", "time" => "12", "id" => "7", "has" => "true", "token" => "abc")
      expect(outcome.tests.pluck("passed")).to eq([true, false, true, false])
    end

    it "is not there before the request is sent", :aggregate_failures do
      outcome = run("pm.environment.set('seen', typeof pm.response);", phase: :pre, response: nil)

      expect(outcome.env_writes).to eq("seen" => "undefined")
    end

    it "cuts a very large body" do
      big = response.merge(body: "x" * 2.megabytes)

      expect(run("pm.environment.set('size', pm.response.text().length);", response: big).env_writes["size"].to_i).to eq(described_class::MAX_BODY)
    end
  end

  describe "variables" do
    it "reads the environment and the run variables and records what is written", :aggregate_failures do
      outcome = run(<<~JS)
        pm.environment.set("seen_host", pm.environment.get("host"));
        pm.environment.set("number", 5);
        pm.environment.set("object", { a: 1 });
        pm.environment.unset("host");
        pm.variables.set("mine", "v");
        pm.variables.set("seen_local", pm.variables.get("local"));
        pm.environment.set("has", [pm.environment.has("host"), pm.environment.has("seen_host"), pm.variables.has("nope")].join());
        pm.environment.set("replaced", pm.variables.replaceIn("{{local}}/{{missing}}"));
        pm.environment.set("all", Object.keys(pm.environment.toObject()).sort().join());
      JS

      expect(outcome.env_writes).to include("seen_host" => "h", "number" => "5", "object" => '{"a":1}', "host" => nil, "has" => "false,true,false", "replaced" => "1/{{missing}}")
      expect(outcome.env_writes["all"]).to eq("has,number,object,replaced,seen_host")
      expect(outcome.var_writes).to eq("mine" => "v", "seen_local" => "1")
    end

    it "treats collection variables as run variables" do
      expect(run("pm.collectionVariables.set('c', 'x');").var_writes).to eq("c" => "x")
    end

    it "ignores writes to names an environment would reject, and caps them", :aggregate_failures do
      outcome = run(<<~JS)
        pm.environment.set("1 bad", "x");
        pm.environment.set("ok", "y".repeat(100000));
        for (let i = 0; i < 80; i++) pm.environment.set("k" + i, "v");
      JS

      expect(outcome.env_writes.keys).not_to include("1 bad")
      expect(outcome.env_writes.size).to eq(described_class::MAX_WRITES)
      expect(outcome.env_writes["ok"].bytesize).to be <= described_class::MAX_VALUE
    end
  end

  describe "pm.request" do
    it "lets a pre-request script change the request", :aggregate_failures do
      outcome = run(<<~JS, phase: :pre, response: nil)
        pm.request.url = pm.request.url + "?a=1";
        pm.request.method = "post";
        pm.request.body = { id: 1 };
        pm.request.headers.add({ key: "X-New", value: 2 });
        pm.request.headers.upsert({ key: "a", value: "changed" });
        pm.request.headers.upsert({ key: "X-Other", value: "o" });
        pm.environment.set("seen", pm.request.headers.get("A") + pm.request.headers.has("x-new") + JSON.stringify(pm.request.headers.toObject()));
      JS

      expect(outcome.request).to include(url: "https://a.test/x?a=1", http_method: "POST", body: '{"id":1}')
      expect(outcome.request[:headers].map { |row| [row["key"], row["value"]] }).to eq([%w[A changed], %w[X-New 2], %w[X-Other o]])
      expect(outcome.env_writes["seen"]).to start_with("changedtrue")
    end

    it "removes headers and clears the body", :aggregate_failures do
      outcome = run("pm.request.headers.remove('a'); pm.request.body = null;", phase: :pre, response: nil)

      expect(outcome.request[:headers]).to be_empty
      expect(outcome.request[:body]).to eq("")
    end

    it "does not let a post-response script change the headers", :aggregate_failures do
      outcome = run("pm.environment.set('has_add', typeof pm.request.headers.add);")

      expect(outcome.env_writes).to eq("has_add" => "undefined")
    end
  end

  describe "console" do
    it "keeps the lines with their level", :aggregate_failures do
      outcome = run(<<~JS)
        console.log("a", 1, { b: 2 });
        console.info("i"); console.debug("d"); console.warn("w"); console.error(new Error("e"));
        console.log(undefined, null, [1]);
      JS

      expect(outcome.logs.map { |line| [line["level"], line["text"]] }).to eq([["log", 'a 1 {"b":2}'], %w[info i], %w[log d], %w[warn w], ["error", "Error: e"], ["log", "undefined null [1]"]])
    end

    it "limits the number and the size of lines", :aggregate_failures do
      outcome = run(<<~JS)
        for (let i = 0; i < 500; i++) console.log("line " + i);
      JS
      expect(outcome.logs.size).to eq(200)

      outcome = run('console.log("x".repeat(100000)); for (let i = 0; i < 100; i++) console.log("y".repeat(2000));')
      expect(outcome.logs.first["text"].length).to eq(2000)
      expect(outcome.logs.sum { |line| line["text"].length }).to be < 70_000
    end
  end

  describe "hostile scripts" do
    it "stops an endless loop", :aggregate_failures do
      stub_const("ENV", ENV.to_h.merge("SHANGO_SCRIPT_TIMEOUT_MS" => "200"))
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      expect(run("while (true) {}").error).to eq("timeout")
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 3
    end

    it "stops a script that eats memory", :aggregate_failures do
      stub_const("ENV", ENV.to_h.merge("SHANGO_SCRIPT_MEMORY_MB" => "8"))

      expect(run('const a = []; while (true) { a.push("x".repeat(100000)); }').error).to match(/memory/i)
    end

    it "survives unbounded recursion" do
      expect(run("function f() { f(); } f();").error).to match(/stack/i)
    end

    it "has no way to the outside", :aggregate_failures do
      outcome = run("pm.environment.set('seen', [typeof require, typeof process, typeof fetch, typeof XMLHttpRequest, typeof std, typeof os, typeof setTimeout, typeof WebSocket, typeof importScripts].join());")

      expect(outcome.env_writes["seen"]).to eq(Array.new(9, "undefined").join(","))
    end

    it "reports syntax errors, thrown errors and thrown non-errors", :aggregate_failures do
      expect(run("this is not javascript").error).to start_with("SyntaxError")
      expect(run('throw new TypeError("nope");').error).to eq("TypeError: nope")
      expect(run('throw "plain";').error).to eq("plain")
    end

    it "keeps what a script did before it failed", :aggregate_failures do
      outcome = run('pm.test("before", () => {}); pm.environment.set("a", "1"); throw new Error("late");')

      expect(outcome.error).to eq("Error: late")
      expect(outcome.tests.pluck("name")).to eq(["before"])
      expect(outcome.env_writes).to eq("a" => "1")
    end

    it "cannot reach another script's context", :aggregate_failures do
      first = run("globalThis.leak = 'secret'; pm.environment.set('a', '1');")
      second = run("pm.environment.set('leak', typeof globalThis.leak);")

      expect(first.error).to be_nil
      expect(second.env_writes).to eq("leak" => "undefined")
    end

    it "does not trust overridden builtins to crash the host", :aggregate_failures do
      outcome = run("JSON.stringify = () => { throw new Error('hijacked'); }; pm.environment.set('a', '1');")

      expect(outcome.error).to be_present
      expect(outcome.env_writes).to eq({})
    end

    it "refuses a script that is too large" do
      expect(run("//" + ("x" * 70_000)).error).to eq("too_large")
    end

    it "copes with invalid UTF-8 in what it is given", :aggregate_failures do
      bad = response.merge(body: "ab\xFF".b)

      expect(run("pm.environment.set('len', pm.response.text().length);", response: bad).error).to be_nil
    end

    it "reports a result it cannot read" do
      allow_any_instance_of(Quickjs::VM).to receive(:call).and_return("x" * 3.megabytes) # rubocop:disable RSpec/AnyInstance

      expect(run("1").error).to eq("result_too_large")
    end

    it "wraps an unexpected engine error" do
      allow(Quickjs::VM).to receive(:new).and_raise(RuntimeError, "engine down\nsecond line")

      expect(run("1").error).to eq("engine down")
    end

    it "names the error when it has no message" do
      allow(Quickjs::VM).to receive(:new).and_raise(RuntimeError, "")

      expect(run("1").error).to eq("RuntimeError")
    end
  end

  describe "limits" do
    it "reads the timeout and memory from the environment with bounds", :aggregate_failures do
      expect(described_class.timeout_ms).to eq(2_000)
      expect(described_class.memory_bytes).to eq(32.megabytes)

      stub_const("ENV", ENV.to_h.merge("SHANGO_SCRIPT_TIMEOUT_MS" => "999999", "SHANGO_SCRIPT_MEMORY_MB" => "9999"))
      expect(described_class.timeout_ms).to eq(10_000)
      expect(described_class.memory_bytes).to eq(128.megabytes)

      stub_const("ENV", ENV.to_h.merge("SHANGO_SCRIPT_TIMEOUT_MS" => "1", "SHANGO_SCRIPT_MEMORY_MB" => "1"))
      expect(described_class.timeout_ms).to eq(100)
      expect(described_class.memory_bytes).to eq(4.megabytes)
    end
  end
end
