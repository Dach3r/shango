require "rails_helper"

RSpec.describe "Workbench response panel escaping" do
  include_context "with workbench project"

  let(:payload) { "<script>alert(1)</script>" }
  let(:execution) { create(:request_execution, api_request:, project:, user:, **attributes) }
  let(:attributes) { {} }

  def panel
    execution
    get workbench_request_path(api_request)
    response.body
  end

  it "escapes the response body in the preview iframe and the editor values", :aggregate_failures do
    body = "<html><script>alert(1)</script>\"><img src=x onerror=alert(1)></html>"
    create(:request_execution, api_request:, project:, user:, content_type: "text/html", response_body: body)
    get workbench_request_path(api_request)

    expect(response.body).not_to include("<script>alert(1)</script>")
    expect(response.body).not_to include("<img src=x")
    expect(response.body).to match(/<iframe[^>]*\ssandbox=""[^>]*srcdoc="&lt;html&gt;/)
  end

  context "with hostile headers, url and error message" do
    let(:attributes) do
      { url: "https://x.test/?q=#{payload}", response_headers: [["X-#{payload}", payload]], request_headers: [["Cookie", payload]],
        status: nil, error_kind: "unknown", error_message: payload }
    end

    it "never renders them as markup", :aggregate_failures do
      expect(panel).not_to include(payload)
      expect(panel).to include("&lt;script&gt;")
    end
  end

  context "when the body is empty, binary or unicode" do
    it "shows the empty body notice" do
      create(:request_execution, api_request:, project:, user:, response_body: "")
      get workbench_request_path(api_request)

      expect(response.body).to include(I18n.t("workbench.executions.empty_body"))
    end

    it "shows the binary notice without a content type", :aggregate_failures do
      create(:request_execution, api_request:, project:, user:, body_omitted: true, content_type: nil, size_bytes: 10)
      get workbench_request_path(api_request)

      expect(response.body).to include(I18n.t("workbench.executions.binary", size: "10 Bytes", type: "—"))
    end

    it "renders unicode bodies" do
      create(:request_execution, api_request:, project:, user:, response_body: "ñandú 日本語 🚀", content_type: "text/plain")
      get workbench_request_path(api_request)

      expect(response.body).to include("ñandú 日本語 🚀")
    end
  end
end
