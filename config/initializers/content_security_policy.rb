# Content Security Policy. Scripts must come from this origin or carry the per-request nonce (the importmap tag does);
# inline styles stay allowed because CodeMirror injects <style> elements and response previews (srcdoc iframes inherit this
# policy) usually carry inline CSS. `form-action` is not restricted: Chrome applies it to redirects, which would block
# the OAuth 2.0 authorization redirect to the provider.
# Set SHANGO_CSP_REPORT_ONLY=true to log violations in the browser console without blocking anything.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src :self
    policy.style_src :self, :unsafe_inline, "https://fonts.googleapis.com"
    policy.font_src :self, :data, "https://fonts.gstatic.com"
    policy.img_src :self, :data, :blob, :https
    policy.connect_src :self
    policy.object_src :none
    policy.base_uri :self
    policy.frame_ancestors :none
  end

  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
  config.content_security_policy_report_only = ActiveModel::Type::Boolean.new.cast(ENV["SHANGO_CSP_REPORT_ONLY"]) == true
end
