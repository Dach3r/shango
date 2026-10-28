module AuditEvents
  # Writes one entry of a project's team history. Names are copied into the metadata so the entry still reads right
  # after the people involved delete their accounts.
  class Record
    include Serviceable

    def initialize(project:, kind:, actor: nil, target: nil, **metadata)
      @project = project
      @kind = kind
      @actor = actor
      @target = target
      @metadata = metadata
    end

    private

    def perform
      Result.success(AuditEvent.create!(project: @project, kind: @kind, actor: @actor, target: @target, metadata: names.merge(@metadata.stringify_keys)))
    end

    def names
      { "actor_name" => @actor&.full_name, "target_name" => @target&.full_name }.compact
    end
  end
end
