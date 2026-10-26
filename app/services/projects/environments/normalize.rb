module Projects
  module Environments
    # Orders submitted variable rows by their position in the form.
    class Normalize
      include Serviceable

      def initialize(attributes:)
        @attributes = attributes.to_h.with_indifferent_access
      end

      private

      def perform
        rows = @attributes[:variables_attributes]
        return @attributes if rows.blank?

        rows = rows.values if rows.respond_to?(:values)
        @attributes.merge(variables_attributes: rows.each_with_index.map { |row, index| row.merge(position: index) })
      end
    end
  end
end
