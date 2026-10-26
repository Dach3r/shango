module ApiClient
  module Tree
    # Places `record` among `siblings` right before `before_id` (or last) and renumbers them.
    class Reposition
      include Serviceable

      def initialize(record:, siblings:, before_id: nil)
        @record = record
        @siblings = siblings
        @before_id = before_id.presence
      end

      private

      def perform
        ordered = @siblings.where.not(id: @record.id).order(:position, :created_at).to_a
        ordered.insert(ordered.index { |sibling| sibling.id == @before_id } || ordered.size, @record)

        @record.class.transaction do
          ordered.each.with_index(1) { |sibling, position| sibling.update_column(:position, position) if sibling.position != position }
        end
        @record
      end
    end
  end
end
