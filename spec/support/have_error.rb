# `expect(record).to have_error(:attribute, :type)`: validating the record adds that error.
RSpec::Matchers.define :have_error do |attribute, type|
  match do |record|
    record.validate
    record.errors.details[attribute].any? { |detail| detail[:error] == type }
  end

  failure_message { |record| "expected #{attribute} to have #{type}, got #{record.errors.details.inspect}" }
end
