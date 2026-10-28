module ApiClient
  module Exports
    # A minimal ZIP archive (stored entries, no compression) for exports that need several files.
    module Zip
      module_function

      def build(files)
        body = "".b
        central = "".b
        files.each do |name, content|
          name = name.b
          data = content.to_s.b
          crc = Zlib.crc32(data)
          offset = body.bytesize
          body << [0x04034b50, 20, 0x0800, 0, 0, 0x21, crc, data.bytesize, data.bytesize, name.bytesize, 0].pack("VvvvvvVVVvv") << name << data
          central << [0x02014b50, 20, 20, 0x0800, 0, 0, 0x21, crc, data.bytesize, data.bytesize, name.bytesize, 0, 0, 0, 0, 0, offset].pack("VvvvvvvVVVvvvvvVV") << name
        end
        central_offset = body.bytesize
        body << central << [0x06054b50, 0, 0, files.size, files.size, central.bytesize, central_offset, 0].pack("VvvvvVVv")
      end
    end
  end
end
