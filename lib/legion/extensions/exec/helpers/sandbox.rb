# frozen_string_literal: true

module Legion
  module Extensions
    module Exec
      module Helpers
        class Sandbox
          def initialize(allowed_commands: Helpers::Constants::ALLOWED_COMMANDS,
                         blocked_patterns: Helpers::Constants::BLOCKED_PATTERNS)
            @allowed_commands = allowed_commands
            @blocked_patterns = blocked_patterns
          end

          def allowed?(command)
            base = base_command(command)

            return { allowed: false, reason: "command '#{base}' is not in the allowlist" } unless allowed_base?(base)

            @blocked_patterns.each do |pattern|
              return { allowed: false, reason: "command matches blocked pattern: #{pattern.source}" } if pattern.match?(command)
            end

            { allowed: true, reason: nil }
          end

          def sanitize(command)
            command.gsub(/[`$()]/, '')
          end

          private

          # Match either the exact allowed string or just the basename of a full path.
          # This lets the venv absolute path (e.g. ~/.legionio/python/bin/python3)
          # and the bare name (python3) both pass the allowlist check.
          def allowed_base?(base)
            @allowed_commands.any? do |entry|
              entry == base || File.basename(entry) == base || File.basename(base) == File.basename(entry)
            end
          end

          def base_command(command)
            command.strip.split(/\s+/).first.to_s
          end
        end
      end
    end
  end
end
