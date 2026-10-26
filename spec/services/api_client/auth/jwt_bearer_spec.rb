require "rails_helper"

RSpec.describe ApiClient::Auth::JwtBearer do
  let(:request) { ApiClient::Auth::Request.new(http_method: "GET", url: "https://a.test/x", headers: {}, body: nil) }
  let(:config) { { "secret" => "s3cret", "payload" => '{"sub":"me"}' } }

  def token_from(request)
    request.headers["Authorization"].split.last
  end

  it "signs an HS256 token into the header", :aggregate_failures do
    described_class.new(config).apply(request)

    payload, header = JWT.decode(token_from(request), "s3cret", true, algorithm: "HS256")
    expect(request.headers["Authorization"]).to start_with("Bearer ")
    expect(payload).to eq("sub" => "me")
    expect(header["alg"]).to eq("HS256")
  end

  it "uses custom prefix and headers", :aggregate_failures do
    described_class.new(config.merge("prefix" => "JWT", "headers" => '{"kid":"k1"}')).apply(request)

    _payload, header = JWT.decode(token_from(request), "s3cret", true, algorithm: "HS256")
    expect(request.headers["Authorization"]).to start_with("JWT ")
    expect(header["kid"]).to eq("k1")
  end

  it "falls back to HS256 for unknown algorithms" do
    described_class.new(config.merge("algorithm" => "none")).apply(request)

    expect(JWT.decode(token_from(request), "s3cret", true, algorithm: "HS256")).to be_present
  end

  it "adds the token to the query" do
    described_class.new(config.merge("add_to" => "query")).apply(request)

    expect(request.url).to match(/\?token=.+/)
  end

  it "uses a custom query param" do
    described_class.new(config.merge("add_to" => "query", "query_param" => "jwt")).apply(request)

    expect(request.url).to match(/\?jwt=.+/)
  end

  it "signs with an RSA key" do
    key = OpenSSL::PKey::RSA.generate(2048)
    described_class.new(config.merge("algorithm" => "RS256", "secret" => key.to_pem)).apply(request)

    expect(JWT.decode(token_from(request), key.public_key, true, algorithm: "RS256")).to be_present
  end

  it "signs with an EC key" do
    key = OpenSSL::PKey::EC.generate("prime256v1")
    described_class.new(config.merge("algorithm" => "ES256", "secret" => key.to_pem)).apply(request)

    expect(JWT.decode(token_from(request), key, true, algorithm: "ES256")).to be_present
  end

  it "wraps key errors" do
    expect { described_class.new(config.merge("algorithm" => "RS256", "secret" => "not a pem")).apply(request) }
      .to raise_error(ApiClient::Auth::ConfigurationError, /Could not sign JWT/)
  end

  it "accepts an empty payload" do
    described_class.new({ "secret" => "s" }).apply(request)

    expect(token_from(request)).to be_present
  end

  it "rejects invalid JSON" do
    expect { described_class.new(config.merge("payload" => "{")).apply(request) }.to raise_error(ApiClient::Auth::ConfigurationError, "JWT payload is not valid JSON")
  end

  it "rejects non-object JSON" do
    expect { described_class.new(config.merge("payload" => "[1]")).apply(request) }.to raise_error(ApiClient::Auth::ConfigurationError, "JWT payload must be a JSON object")
  end

  it "requires a secret" do
    expect { described_class.new({}).apply(request) }.to raise_error(ApiClient::Auth::ConfigurationError)
  end
end
