# frozen_string_literal: true

module Legion
  module Extensions
    module Exec
      module Helpers
        module ResultParser
          module_function

          def parse_rspec(output)
            examples = 0
            failures = 0
            pending  = 0

            if (match = output.match(/(\d+)\s+examples?,\s+(\d+)\s+failures?/))
              examples = match[1].to_i
              failures = match[2].to_i
            end

            if (match = output.match(/(\d+)\s+pending/))
              pending = match[1].to_i
            end

            { examples: examples, failures: failures, pending: pending, passed: failures.zero? }
          end

          def parse_rubocop(output)
            files    = 0
            offenses = 0

            if (match = output.match(/(\d+)\s+files?\s+inspected,\s+(\d+)\s+offenses?\s+detected/))
              files    = match[1].to_i
              offenses = match[2].to_i
            end

            { files: files, offenses: offenses, clean: offenses.zero? }
          end

          def parse_git_status(output)
            modified   = []
            untracked  = []
            deleted    = []

            output.each_line do |line|
              code = line[0..1].strip
              file = line[3..].strip

              case code
              when 'M', 'MM', 'AM'
                modified << file
              when '??'
                untracked << file
              when 'D', 'MD'
                deleted << file
              end
            end

            {
              clean:     modified.empty? && untracked.empty? && deleted.empty?,
              modified:  modified,
              untracked: untracked,
              deleted:   deleted
            }
          end
        end
      end
    end
  end
end
