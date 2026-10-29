module Network
  module EmailChecks
    # The `tag=value; tag=value` syntax shared by DKIM and DMARC records.
    module Tags
      module_function

      def parse(record)
        record.split(";").filter_map do |part|
          key, value = part.split("=", 2).map(&:strip)
          [key.downcase, value.to_s] if key.present? && !value.nil?
        end.to_h
      end
    end
  end
end
