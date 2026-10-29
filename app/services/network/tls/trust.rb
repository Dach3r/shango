module Network
  module Tls
    # Whether the certificates a server sent build a chain to a root the system trusts. Time is left out on purpose:
    # an expired certificate is reported as such, not as untrusted.
    module Trust
      REASONS = {
        OpenSSL::X509::V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT => "self_signed",
        OpenSSL::X509::V_ERR_SELF_SIGNED_CERT_IN_CHAIN => "untrusted_root",
        OpenSSL::X509::V_ERR_UNABLE_TO_GET_ISSUER_CERT => "unknown_issuer",
        OpenSSL::X509::V_ERR_UNABLE_TO_GET_ISSUER_CERT_LOCALLY => "unknown_issuer",
        OpenSSL::X509::V_ERR_UNABLE_TO_VERIFY_LEAF_SIGNATURE => "unknown_issuer"
      }.freeze

      module_function

      def check(chain, store: default_store)
        store.flags = OpenSSL::X509::V_FLAG_NO_CHECK_TIME
        store.purpose = OpenSSL::X509::PURPOSE_SSL_SERVER
        return { status: "trusted", reason: nil, code: nil } if store.verify(chain.first, chain.drop(1))

        { status: "untrusted", reason: REASONS.fetch(store.error, "other"), code: store.error }
      end

      def default_store
        OpenSSL::X509::Store.new.tap(&:set_default_paths)
      end
    end
  end
end
