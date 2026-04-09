# frozen_string_literal: true

module Legion
  module Extensions
    module Exec
      module Helpers
        module Constants
          DEFAULT_TIMEOUT  = 120_000 # 120 seconds in ms
          MAX_TIMEOUT      = 600_000 # 10 minutes in ms
          MAX_OUTPUT_BYTES = 1_048_576 # 1 MB

          LEGION_PYTHON_VENV = File.expand_path('~/.legionio/python').freeze

          BASE_ALLOWED_COMMANDS = %w[
            bundle git gh ruby rspec rubocop ls cat mkdir cp mv rm touch echo wc head tail
            python3 python pip3 pip
          ].freeze

          ALLOWED_COMMANDS = BASE_ALLOWED_COMMANDS

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

          module_function

          def venv_python
            "#{LEGION_PYTHON_VENV}/bin/python3"
          end

          def venv_pip
            "#{LEGION_PYTHON_VENV}/bin/pip"
          end

          def venv_exists?
            File.exist?("#{LEGION_PYTHON_VENV}/pyvenv.cfg")
          end
        end
      end
    end
  end
end
