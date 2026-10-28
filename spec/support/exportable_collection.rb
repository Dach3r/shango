# A collection that touches every branch of the exporters: nested folders, every body type, every auth strategy
# and an environment with a secret, a disabled and a base URL variable.
RSpec.shared_context "with exportable collection" do
  let(:export_project) { create(:project) }
  let(:export_collection) do
    create(:collection, project: export_project, name: "Pet Store", description: "All pets", auth_type: "basic", auth_config: { "username" => "root", "password" => "hunter2" }).tap do |collection|
      users = create(:folder, collection:, name: "Users", auth_type: "bearer", auth_config: { "token" => "tok-123", "prefix" => "Token" })
      admin = create(:folder, collection:, name: "Admin", parent: users, auth_type: "inherit")
      none = create(:folder, collection:, name: "Open", auth_type: "none")

      create(:api_request, collection:, name: "List", url: "{{baseUrl}}/users/{{id}}?limit=10", description: "Lists", body_type: "json", body: '{"a":1}',
                           query_params: [{ "key" => "limit", "value" => "10" }, { "key" => "page", "value" => "2", "enabled" => false, "description" => "Page" }],
                           headers: [{ "key" => "X-Trace", "value" => "{{$guid}}" }, { "key" => "Content-Type", "value" => "application/json" }, { "key" => "X-Date", "value" => "{{$timestamp}}", "enabled" => false }],
                           settings: { "follow_redirects" => false })
      create(:api_request, collection:, name: "List again", url: "{{baseUrl}}/users/{{id}}")
      create(:api_request, collection:, folder: users, name: "Create", http_method: "POST", url: "{{missing}}/users", body_type: "xml", body: "<a/>", auth_type: "api_key", auth_config: { "key" => "k", "value" => "v1", "add_to" => "query" })
      create(:api_request, collection:, folder: users, name: "Note", http_method: "PUT", url: "users", body_type: "text", body: "hello {{name}}", auth_type: "none")
      create(:api_request, collection:, folder: admin, name: "Form", http_method: "POST", url: "https://api.example.com/forms?x=1", body_type: "form_urlencoded", auth_type: "digest", auth_config: { "username" => "d", "password" => "dp" },
                           body_form: [{ "key" => "a", "value" => "{{$guid}}" }])
      create(:api_request, collection:, folder: admin, name: "Upload", http_method: "POST", url: "https://api.example.com/upload", body_type: "multipart", auth_type: "aws_sigv4",
                           auth_config: { "access_key" => "AK", "secret_key" => "SK", "session_token" => "ST", "region" => "us-east-1", "service" => "s3" },
                           body_form: [{ "key" => "title", "value" => "x", "type" => "text" }, { "key" => "file", "value" => "a.png", "type" => "file", "enabled" => false }])
      create(:api_request, collection:, folder: none, name: "Query", http_method: "POST", url: "https://api.example.com/graphql", body_type: "graphql", body: "{ pets }", graphql_variables: '{"a":1}',
                           auth_type: "oauth2", auth_config: { "grant_type" => "client_credentials", "token_url" => "https://auth/token", "client_id" => "cid", "client_secret" => "csec", "access_token" => "at-1" })
      create(:api_request, collection:, folder: none, name: "Query plain", http_method: "DELETE", url: "https://api.example.com/graphql", body_type: "graphql", body: "{ x }", auth_type: "oauth2",
                           auth_config: { "grant_type" => "implicit", "token_url" => "https://auth/token" })
      create(:api_request, collection:, folder: none, name: "Binary", http_method: "PATCH", url: "https://api.example.com/bin", body_type: "binary", auth_type: "jwt_bearer", auth_config: { "secret" => "jwt-secret", "algorithm" => "HS256" })
      create(:api_request, collection:, folder: none, name: "Key", http_method: "OPTIONS", url: "https://api.example.com/key", auth_type: "api_key", auth_config: { "key" => "X-Key", "value" => "kv" })
      create(:api_request, collection:, folder: none, name: "Token", http_method: "HEAD", url: "https://api.example.com/token", auth_type: "bearer", auth_config: { "token" => "b-1" })
    end
  end
  let!(:export_environment) do
    create(:environment, project: export_project, name: "Staging").tap do |environment|
      create(:variable, environment:, key: "baseUrl", value: "https://stg.example.com/")
      create(:variable, environment:, key: "TOKEN", value: "s3cret", secret: true)
      create(:variable, environment:, key: "OFF", value: "x", enabled: false)
    end
  end
  let(:credentials) { ApiClient::Exports::Credentials.new(include: false) }
  let(:environments) { export_project.environments.ordered.to_a }
end
