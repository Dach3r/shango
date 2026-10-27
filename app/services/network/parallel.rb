module Network
  # Runs a block for every item on a bounded number of threads and returns the results in input order.
  # Network checks are I/O bound and short, so plain threads are enough; nothing is shared between them.
  module Parallel
    def self.map(items, limit:, &block)
      queue = Queue.new
      items.each_with_index { |item, index| queue << [item, index] }
      queue.close

      results = Array.new(items.size)
      threads = Array.new([limit, items.size].min) do
        Thread.new do
          while (item, index = queue.pop)
            results[index] = block.call(item)
          end
        end
      end
      threads.each { |thread| thread.report_on_exception = false }

      ActiveSupport::Dependencies.interlock.permit_concurrent_loads { threads.each(&:join) }
      results
    end
  end
end
