module Network
  module Dns
    module Resolvers
      Resolver = Data.define(:name, :ip, :group)

      PUBLIC = [
        ["Google", "8.8.8.8"], ["Cloudflare", "1.1.1.1"], ["Quad9", "9.9.9.9"], ["OpenDNS", "208.67.222.222"],
        ["Verisign", "64.6.64.6"], ["AdGuard", "94.140.14.14"], ["CleanBrowsing", "185.228.168.9"], ["Lumen", "4.2.2.1"]
      ].map { |name, ip| Resolver.new(name:, ip:, group: :public) }.freeze
      LOOKUP_IP = "1.1.1.1".freeze
      LIMIT = 8

      def self.authoritative(domain)
        labels = domain.split(".")
        zone = Array.new([labels.size - 1, 1].max) { |index| labels[index..].join(".") }.lazy.map { |name| ask(name, "NS") }.find { |answer| answer.status == :ok }
        return [] unless zone

        Parallel.map(zone.answers.map { |name| name.downcase.delete_suffix(".") }, limit: LIMIT) do |name|
          Resolver.new(name:, ip: address(name), group: :authoritative)
        end
      end

      def self.address(name)
        %w[A AAAA].each do |type|
          answer = ask(name, type)
          return answer.answers.first if answer.status == :ok
        end
        nil
      end

      def self.ask(name, type)
        Query.call(ip: LOOKUP_IP, name:, type:)
      end
      private_class_method :address, :ask
    end
  end
end
