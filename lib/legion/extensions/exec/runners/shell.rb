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

            start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
            timeout_secs = [timeout, Helpers::Constants::MAX_TIMEOUT].min / 1000.0

            begin
              stdout, stderr, status = Timeout.timeout(timeout_secs) do
                Open3.capture3(env, command, chdir: cwd)
              end
            rescue Timeout::Error
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

            Legion::Logging.debug("[lex-exec] exit=#{exit_code} duration=#{duration_ms}ms cmd=#{command}")

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
