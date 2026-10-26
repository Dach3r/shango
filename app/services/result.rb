# Outcome of a service call. `record` carries the primary object (valid or not) and `data` any extra payload.
class Result
  attr_reader :record, :data, :error

  def self.success(record = nil, **data)
    new(success: true, record:, data:)
  end

  def self.failure(record = nil, error: nil, **data)
    new(success: false, record:, error:, data:)
  end

  def initialize(success:, record: nil, error: nil, data: {})
    @success = success
    @record = record
    @error = error
    @data = data
  end

  def success?
    @success
  end

  def failure?
    !success?
  end
end
