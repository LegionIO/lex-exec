# frozen_string_literal: true

module Legion
  module Extensions
    module Exec
      module Helpers
        class AuditLog
          MAX_ENTRIES = 1000

          def initialize
            @entries = []
            @mutex   = Mutex.new
          end

          def record(command:, cwd:, exit_code:, duration_ms:, truncated: false)
            entry = {
              command:     command,
              cwd:         cwd,
              exit_code:   exit_code,
              duration_ms: duration_ms,
              truncated:   truncated,
              executed_at: Time.now.utc.iso8601
            }

            @mutex.synchronize do
              @entries << entry
              @entries.shift while @entries.size > MAX_ENTRIES
            end
          end

          def entries(limit: 50)
            @mutex.synchronize { @entries.last(limit) }
          end

          def stats
            @mutex.synchronize do
              total    = @entries.size
              success  = @entries.count { |e| e[:exit_code].zero? }
              failure  = total - success
              avg_dur  = total.zero? ? 0 : (@entries.sum { |e| e[:duration_ms] } / total.to_f).round(2)

              { total: total, success: success, failure: failure, avg_duration_ms: avg_dur }
            end
          end

          def clear
            @mutex.synchronize { @entries.clear }
          end
        end
      end
    end
  end
end
