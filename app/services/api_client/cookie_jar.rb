module ApiClient
  # Per project and environment cookie store: remembers the cookies servers set (Set-Cookie) and replays the matching
  # ones on later requests, so session based flows (sign in, then call an endpoint that needs the session) work.
  class CookieJar
    MAX_VALUE_LENGTH = 4096
    SPLIT_SET_COOKIE = /,(?=\s*[^;,=\s]+=)/

    def initialize(project:, environment: nil)
      @project = project
      @environment = environment
    end

    # The Cookie header value for this URL, or nil when no stored cookie applies.
    def header(url)
      uri = parse_url(url) or return
      cookies = scope.live.select { |cookie| cookie.matches?(uri) }
      return if cookies.empty?

      cookies.sort_by { |cookie| [-cookie.path.length, cookie.created_at] }.map { |cookie| "#{cookie.name}=#{cookie.value}" }.join("; ")
    end

    # `set_cookie` is the Set-Cookie header as received (several cookies come merged into one comma separated value).
    def store(url, set_cookie)
      return if set_cookie.blank?

      uri = parse_url(url) or return
      set_cookie.to_s.split(SPLIT_SET_COOKIE).each { |line| remember(uri, parse(line)) }
      scope.expired.delete_all
      trim
    end

    private

    def parse_url(url)
      URI.parse(url)
    rescue URI::InvalidURIError
      nil
    end

    def scope
      Cookie.for_jar(@project, @environment)
    end

    def parse(line)
      pair, *attributes = line.split(";").map(&:strip)
      name, value = pair.to_s.split("=", 2)
      return if name.blank? || value.nil? || value.length > MAX_VALUE_LENGTH

      attributes = attributes.to_h { |attribute| attribute.split("=", 2).then { |key, val| [key.to_s.downcase, val.to_s.strip] } }
      { name: name.strip, value: value.strip, attributes: }
    end

    def remember(uri, parsed)
      return unless parsed

      host = uri.host.to_s.downcase
      domain = parsed[:attributes]["domain"].to_s.delete_prefix(".").downcase
      return if domain.present? && !domain_allowed?(host, domain)

      cookie = scope.find_or_initialize_by(domain: domain.presence || host, path: path_for(uri, parsed[:attributes]["path"]), name: parsed[:name])
      expires_at = expiry(parsed[:attributes])
      return cookie.destroy if expires_at && expires_at <= Time.current

      cookie.update!(
        value: parsed[:value], expires_at:, host_only: domain.blank?, secure: parsed[:attributes].key?("secure"), http_only: parsed[:attributes].key?("httponly")
      )
    end

    def domain_allowed?(host, domain)
      host == domain || (host.end_with?(".#{domain}") && !host.match?(/\A[\d.]+\z|:/) && domain.include?("."))
    end

    def path_for(uri, attribute)
      return attribute if attribute.to_s.start_with?("/")

      default = uri.path.to_s.rpartition("/").first
      default.presence || "/"
    end

    def expiry(attributes)
      max_age = attributes["max-age"]
      return Time.current + max_age.to_i.seconds if max_age.to_s.match?(/\A-?\d+\z/)

      Time.zone.parse(attributes["expires"]) if attributes["expires"].present?
    rescue ArgumentError
      nil
    end

    def trim
      excess = scope.count - Cookie::MAX_PER_JAR
      scope.order(:updated_at).limit(excess).destroy_all if excess.positive?
    end
  end
end
