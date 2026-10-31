module ApiClient
  module Runs
    # A finished (or running) run as a file for CI and other tools: `:json`, or `:junit` XML with one test suite per request and one
    # test case per assertion, extractor or request without tests. Result#record is the String. Text follows the current locale.
    class Report
      include Serviceable

      FORMATS = %i[json junit].freeze

      def initialize(run:, format:)
        @run = run
        @format = format.to_sym
      end

      private

      def perform
        Result.success(@format == :junit ? junit : JSON.pretty_generate(json))
      end

      def json
        {
          id: @run.id, status: @run.status, collection: @run.collection.name, folder: @run.folder&.name, environment: @run.environment&.name,
          total: @run.total_count, passed: @run.passed_count, failed: @run.failed_count, options: @run.options,
          started_at: @run.started_at&.iso8601, finished_at: @run.finished_at&.iso8601,
          items: @run.items.map { |item| item_json(item) }
        }
      end

      def item_json(item)
        {
          name: item.request_name, method: item.http_method, url: item.url, status: item.status, http_status: item.http_status, duration_ms: item.duration_ms,
          error_kind: item.error_kind, error_message: item.error_message,
          tests: item.test_results.map { |outcome| outcome.slice("kind", "status", "source", "target", "operator", "expected", "actual", "error", "variable").merge("title" => Assertions::Describe.title(outcome)) }
        }
      end

      def junit
        suites = @run.items.map { |item| [item, cases_for(item)] }
        all = suites.flat_map(&:last)
        Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
          xml.testsuites(name: @run.scope_name, tests: all.size, failures: failures(all), skipped: all.count { |kase| kase[:skipped] }, time: seconds(@run.duration)) do
            suites.each { |item, cases| suite(xml, item, cases) }
          end
        end.to_xml
      end

      # A request that did not run is one skipped case; otherwise one case per assertion or extractor that ran, a case for a request
      # that could not be sent, or a single passing case when it has no tests.
      def cases_for(item)
        return [{ name: item.request_name, skipped: true }] unless item.passed? || item.failed?

        cases = item.test_results.reject { |outcome| outcome["status"] == "warning" }.map do |outcome|
          title = Assertions::Describe.title(outcome)
          { name: title, failure: (Assertions::Describe.detail(outcome) || title if outcome["status"] == "failed") }
        end
        cases << { name: item.request_name, failure: item.error_message.presence || item.error_kind } if item.error?
        cases.presence || [{ name: item.request_name }]
      end

      def suite(xml, item, cases)
        xml.testsuite(name: item.request_name, tests: cases.size, failures: failures(cases), skipped: cases.count { |kase| kase[:skipped] }, time: seconds(item.duration_ms.to_f / 1000)) do
          cases.each do |kase|
            xml.testcase(name: kase[:name], classname: item.request_name) do
              xml.failure(message: kase[:failure]) if kase[:failure]
              xml.skipped if kase[:skipped]
            end
          end
        end
      end

      def failures(cases)
        cases.count { |kase| kase[:failure] }
      end

      def seconds(value)
        format("%.3f", value.to_f)
      end
    end
  end
end
