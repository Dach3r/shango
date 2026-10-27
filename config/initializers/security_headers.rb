Rails.application.config.action_dispatch.default_headers.merge!(
  "Permissions-Policy" => "camera=(), microphone=(), geolocation=(), payment=(), usb=()"
)
