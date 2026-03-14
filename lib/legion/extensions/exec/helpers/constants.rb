# frozen_string_literal: true

module Legion
  module Extensions
    module Exec
      module Helpers
        module Constants
          DEFAULT_TIMEOUT   = 120_000 # 120 seconds in ms
          MAX_TIMEOUT       = 600_000 # 10 minutes in ms
          MAX_OUTPUT_BYTES  = 1_048_576 # 1 MB

          ALLOWED_COMMANDS = %w[
            bundle git gh ruby rspec rubocop ls cat mkdir cp mv rm touch echo wc head tail
          ].freeze

          BLOCKED_PATTERNS = [
            %r{rm\s+-rf\s+/},
            /rm\s+-rf\s+~/,
            /rm\s+-rf\s+\.\./,
            /sudo/,
            /chmod\s+777/,
            /curl.*\|.*sh/,
            %r{>\s*/etc},
            %r{>\s*/usr}
          ].freeze

          AUDIT_FIELDS = %i[command cwd exit_code duration_ms executed_at truncated].freeze
        end
      end
    end
  end
end
