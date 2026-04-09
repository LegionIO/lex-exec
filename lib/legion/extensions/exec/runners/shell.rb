# frozen_string_literal: true

require 'open3'
require 'timeout'

module Legion
  module Extensions
    module Exec
      module Runners
        module Shell
          extend self

          def execute(command:, cwd: Dir.pwd, timeout: Helpers::Constants::DEFAULT_TIMEOUT, env: {}, **)
            check = default_sandbox.allowed?(command)
            return { success: false, error: :blocked, reason: check[:reason] } unless check[:allowed]

            # Rewrite bare `python3` / `python` / `pip3` / `pip` invocations to use
            # the Legion-managed venv interpreter so scripts always run inside the
            # correct environment with pre-installed packages (python-pptx, etc.).
            command = rewrite_python_command(command)

            start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
            timeout_secs = [timeout, Helpers::Constants::MAX_TIMEOUT].min / 1000.0

            begin
              stdout, stderr, status = Timeout.timeout(timeout_secs) do
                Open3.capture3(env, command, chdir: cwd)
              end
            rescue Timeout::Error => _e
              return { success: false, error: :timeout, timeout_ms: timeout }
            rescue ArgumentError => e
              return { success: false, error: e.message }
            end

            duration_ms = ((::Process.clock_gettime(::Process::CLOCK_MONOTONIC) - start_time) * 1000).round
            exit_code   = status.exitstatus.to_i
            truncated   = false

            if stdout.bytesize > Helpers::Constants::MAX_OUTPUT_BYTES
              stdout    = stdout.byteslice(0, Helpers::Constants::MAX_OUTPUT_BYTES)
              truncated = true
            end

            stderr = stderr.byteslice(0, Helpers::Constants::MAX_OUTPUT_BYTES) if stderr.bytesize > Helpers::Constants::MAX_OUTPUT_BYTES

            audit_log.record(command: command, cwd: cwd, exit_code: exit_code,
                             duration_ms: duration_ms, truncated: truncated)

            Legion::Logging.debug("[lex-exec] exit=#{exit_code} duration=#{duration_ms}ms cmd=#{command}") # rubocop:disable Legion/HelperMigration/DirectLogging

            {
              success:     exit_code.zero?,
              stdout:      stdout,
              stderr:      stderr,
              exit_code:   exit_code,
              duration_ms: duration_ms,
              truncated:   truncated
            }
          end

          def audit(limit: 50, **)
            { success: true, entries: audit_log.entries(limit: limit), stats: audit_log.stats }
          end

          private

          # Replace bare `python3`, `python`, `pip3`, `pip` at the start of a command
          # with the absolute venv paths — but only when the venv actually exists.
          # Full absolute paths that already point into the venv are left unchanged.
          def rewrite_python_command(command)
            venv = Helpers::Constants::LEGION_PYTHON_VENV
            return command unless File.exist?("#{venv}/pyvenv.cfg")

            python = Helpers::Constants::LEGION_PYTHON
            pip    = Helpers::Constants::LEGION_PIP

            command
              .sub(/\Apython3(\s|\z)/, "#{python}\\1")
              .sub(/\Apython(\s|\z)/,  "#{python}\\1")
              .sub(/\Apip3(\s|\z)/,    "#{pip}\\1")
              .sub(/\Apip(\s|\z)/,     "#{pip}\\1")
          end

          def default_sandbox
            @default_sandbox ||= Helpers::Sandbox.new
          end

          def audit_log
            @audit_log ||= Helpers::AuditLog.new
          end
        end
      end
    end
  end
end
