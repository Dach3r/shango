module Network
  module Lookups
    # Reads the `entities` of an RDAP answer. Only the registrar, the organization that holds a network and abuse
    # contacts are ever looked at: registrant, administrative and technical contacts are never read, so no personal
    # data is kept.
    module Entities
      module_function

      # The first entity (searched through nested ones too) that has the role.
      def find(entities, role)
        Array(entities).grep(Hash).each do |entity|
          return entity if Array(entity["roles"]).include?(role)

          nested = find(entity["entities"], role)
          return nested if nested
        end
        nil
      end

      def property(entity, name)
        properties = Array(Array(entity["vcardArray"])[1]).grep(Array)
        Clean.text(properties.find { |property| property[0] == name }&.[](3))
      end

      def registrar(entities)
        entity = find(entities, "registrar")
        return unless entity

        iana = Array(entity["publicIds"]).grep(Hash).find { |id| id["type"] == "IANA Registrar ID" }
        { name: property(entity, "fn") || Clean.text(entity["handle"]), iana_id: (Clean.text(iana["identifier"].to_s) if iana) }
      end

      # An organization only: a network held by a person has no name worth showing.
      def organization(entities)
        entity = find(entities, "registrant")
        property(entity, "fn") if entity && property(entity, "kind") == "org"
      end

      def abuse(entities)
        entity = find(entities, "abuse")
        return unless entity

        contact = { email: property(entity, "email"), phone: property(entity, "tel")&.delete_prefix("tel:") }
        contact if contact.values.any?
      end
    end
  end
end
