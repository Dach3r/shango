module Network
  module Tls
    # Plain data of an X.509 certificate, ready to show and to store: names, validity, key, signature and fingerprint.
    module Certificate
      MAX_NAMES = 100
      CURVES = { "prime256v1" => "P-256", "secp384r1" => "P-384", "secp521r1" => "P-521" }.freeze

      module_function

      def describe(cert)
        names = alt_names(cert)
        {
          subject: entity(cert.subject), issuer: entity(cert.issuer), self_signed: cert.subject.cmp(cert.issuer).zero?,
          names: names.first(MAX_NAMES), names_count: names.size,
          not_before: cert.not_before.utc.iso8601, not_after: cert.not_after.utc.iso8601,
          serial: cert.serial.to_s(16).rjust(2, "0"), key: key(cert), signature: cert.signature_algorithm,
          sha256: OpenSSL::Digest::SHA256.hexdigest(cert.to_der).upcase.scan(/../).join(":")
        }
      end

      # One line of the chain the server sent.
      def summarize(cert)
        { subject: entity(cert.subject), issuer: entity(cert.issuer), not_after: cert.not_after.utc.iso8601, self_signed: cert.subject.cmp(cert.issuer).zero? }
      end

      # The common name, else the organization, else the whole distinguished name.
      def entity(x509)
        fields = x509.to_a.to_h { |oid, value, _type| [oid, value] }
        { name: fields["CN"] || fields["O"] || x509.to_s(OpenSSL::X509::Name::RFC2253), organization: fields["O"] }
      end

      def alt_names(cert)
        extension = cert.extensions.find { |item| item.oid == "subjectAltName" }
        return [] unless extension

        extension.value.split(/,\s*/).filter_map do |entry|
          type, value = entry.split(":", 2)
          value if ["DNS", "IP Address"].include?(type)
        end
      end

      def key(cert)
        key = cert.public_key
        case key
        when OpenSSL::PKey::RSA then { type: "RSA", bits: key.n.num_bits, curve: nil }
        when OpenSSL::PKey::EC then { type: "EC", bits: key.group.degree, curve: CURVES.fetch(key.group.curve_name, key.group.curve_name) }
        else { type: key.oid, bits: nil, curve: nil }
        end
      end
    end
  end
end
