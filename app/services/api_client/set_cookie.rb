module ApiClient
  # Reads Set-Cookie headers: HTTP clients hand several cookies back merged into one comma separated value.
  module SetCookie
    SPLIT = /,(?=\s*[^;,=\s]+=)/
    Parsed = Struct.new(:name, :value, :attributes, keyword_init: true)

    module_function

    def split(header)
      header.to_s.split(SPLIT).map(&:strip).compact_blank
    end

    def parse(line, max_value_length: nil)
      pair, *attributes = line.split(";").map(&:strip)
      name, value = pair.to_s.split("=", 2)
      return if name.blank? || value.nil? || (max_value_length && value.length > max_value_length)

      attributes = attributes.to_h { |attribute| attribute.split("=", 2).then { |key, val| [key.to_s.strip.downcase, val.to_s.strip] } }
      Parsed.new(name: name.strip, value: value.strip, attributes:)
    end
  end
end
