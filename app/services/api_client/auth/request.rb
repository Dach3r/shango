module ApiClient
  module Auth
    # The mutable view of an outgoing request that strategies sign or decorate.
    Request = Struct.new(:http_method, :url, :headers, :body, keyword_init: true) do
      def header?(name)
        headers.keys.any? { |key| key.casecmp?(name) }
      end

      def add_query(name, value)
        uri = URI.parse(url)
        pair = "#{CGI.escape(name.to_s)}=#{CGI.escape(value.to_s)}"
        uri.query = [uri.query.presence, pair].compact.join("&")
        self.url = uri.to_s
      end
    end
  end
end
