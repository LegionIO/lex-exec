# frozen_string_literal: true

module Legion
  module Extensions
    module Exec
      module Helpers
        module Constants
          DEFAULT_TIMEOUT  = 120_000 # 120 seconds in ms
          MAX_TIMEOUT      = 600_000 # 10 minutes in ms
          MAX_OUTPUT_BYTES = 1_048_576 # 1 MB

          # Resolve the Legion-managed Python venv interpreter and pip at runtime.
          # Falls back to bare `python3` / `pip3` if the venv hasn't been created yet
          # (e.g. during a fresh install before `legionio setup python` has run).
          LEGION_PYTHON_VENV = File.expand_path('~/.legionio/python').freeze
          LEGION_PYTHON      = File.exist?("#{LEGION_PYTHON_VENV}/bin/python3") \
                                 ? "#{LEGION_PYTHON_VENV}/bin/python3" \
                                 : 'python3'
          LEGION_PIP         = File.exist?("#{LEGION_PYTHON_VENV}/bin/pip") \
                                 ? "#{LEGION_PYTHON_VENV}/bin/pip" \
                                 : 'pip3'

          ALLOWED_COMMANDS = (
            %w[
              bundle git gh ruby rspec rubocop ls cat mkdir cp mv rm touch echo wc head tail
            ] + [LEGION_PYTHON, 'python3', LEGION_PIP, 'pip3']
          ).uniq.freeze

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
