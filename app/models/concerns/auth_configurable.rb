# Authentication settings stored on collections, folders and requests.
# `auth_type` names a strategy in ApiClient::Auth::Registry (or `inherit` where allowed);
# `auth_config` holds its credentials, encrypted at rest.
module AuthConfigurable
  extend ActiveSupport::Concern

  INHERIT = "inherit".freeze

  included do
    serialize :auth_config, type: Hash, coder: JSON
    encrypts :auth_config

    validates :auth_type, inclusion: { in: ->(record) { record.allowed_auth_types } }
  end

  def allowed_auth_types
    ApiClient::Auth::Registry.keys
  end

  def inherits_auth?
    auth_type == INHERIT
  end
end
