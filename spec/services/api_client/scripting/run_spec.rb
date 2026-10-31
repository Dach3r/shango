require "rails_helper"

RSpec.describe ApiClient::Scripting::Run do
  let(:request) { { url: "https://a.test/x", http_method: "GET", headers: [], body: "" } }
  let(:environment) { { "host" => "h" } }
  let(:phase) { :pre }
  let(:response) { nil }

  def script(source, level: :request, name: "Req")
    described_class::Script.new(level:, name:, source:)
  end

  def run(*scripts, **options)
    described_class.call(phase:, scripts:, environment:, request:, response:, **options).record
  end

  it "runs the scripts in order, each seeing what the earlier ones wrote", :aggregate_failures do
    state = run(
      script("pm.environment.set('a', '1'); pm.variables.set('v', 'x'); pm.request.url += '?one';"),
      script("pm.environment.set('b', pm.environment.get('a') + '2'); pm.variables.set('w', pm.variables.get('v') + 'y'); pm.request.url += '&two';")
    )

    expect(state.error).to be_nil
    expect(state.env_writes).to eq("a" => "1", "b" => "12")
    expect(state.var_writes).to eq("v" => "x", "w" => "xy")
    expect(state.request[:url]).to eq("https://a.test/x?one&two")
  end

  it "lets a later script see an unset", :aggregate_failures do
    state = run(script("pm.environment.unset('host');"), script("pm.environment.set('seen', String(pm.environment.has('host')));"))

    expect(state.env_writes).to eq("host" => nil, "seen" => "false")
  end

  it "starts from the variables it is given" do
    expect(run(script("pm.variables.set('seen', pm.variables.get('given'));"), variables: { "given" => "g" }).var_writes).to eq("seen" => "g")
  end

  it "collects tests and console lines of all scripts", :aggregate_failures do
    state = run(script("pm.test('one', () => {}); console.log('a');"), script("pm.test('two', () => {}); console.log('b');"))

    expect(state.tests.pluck("name")).to eq(%w[one two])
    expect(state.logs.pluck("text")).to eq(%w[a b])
  end

  it "stops at the first script that fails and says where", :aggregate_failures do
    state = run(script("throw new Error('first');", level: :folder, name: "Auth"), script("pm.environment.set('never', '1');"))

    expect(state.error).to eq("Pre-request script of folder Auth: Error: first")
    expect(state.env_writes).to eq({})
  end

  it "names the collection and the request too", :aggregate_failures do
    expect(run(script("throw new Error('c');", level: :collection, name: "Pets")).error).to eq("Pre-request script of collection Pets: Error: c")
    expect(run(script("throw new Error('r');", level: :request, name: "Login")).error).to eq("Pre-request script of request Login: Error: r")
  end

  it "keeps the request of the script that failed unchanged by later ones" do
    state = run(script("pm.request.url = 'https://changed.test';"), script("throw new Error('x');"))

    expect(state.request[:url]).to eq("https://changed.test")
  end

  it "limits the tests and the console lines it keeps" do
    scripts = Array.new(3) { script("for (let i = 0; i < 60; i++) { pm.test('t' + i, () => {}); console.log('l' + i); }") }
    state = run(*scripts)

    expect([state.tests.size, state.logs.size]).to eq([100, 180])
  end

  context "after the response" do
    let(:phase) { :post }
    let(:response) { { status: 200, status_text: "OK", headers: [], body: "{}", duration_ms: 1 } }

    it "leaves the request as it was", :aggregate_failures do
      state = run(script("pm.test('ok', () => pm.response.to.have.status(200));"))

      expect(state.request).to eq(request)
      expect(state.tests.first).to include("passed" => true)
      expect(I18n.t("workbench.automation.phases.post")).to eq("Post-response script")
    end

    it "words an error with the phase" do
      expect(run(script("throw new Error('x');")).error).to start_with("Post-response script of request Req")
    end
  end
end
