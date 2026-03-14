# frozen_string_literal: true

module Legion
  module Extensions
    module Exec
      module Runners
        module Bundler
          module_function

          def install(path:, **)
            Runners::Shell.execute(command: 'bundle install', cwd: path, timeout: 300_000)
          end

          def exec_rspec(path:, format: 'progress', **)
            result = Runners::Shell.execute(
              command: "bundle exec rspec --format #{format}",
              cwd:     path,
              timeout: 300_000
            )
            return result unless result[:stdout] || result[:stderr]

            raw     = result[:stdout] || result[:stderr] || ''
            parsed  = Helpers::ResultParser.parse_rspec(raw)
            result.merge(parsed: parsed)
          end

          def exec_rubocop(path:, autocorrect: false, **)
            cmd    = autocorrect ? 'bundle exec rubocop -A' : 'bundle exec rubocop'
            result = Runners::Shell.execute(command: cmd, cwd: path, timeout: 120_000)
            return result unless result[:stdout]

            parsed = Helpers::ResultParser.parse_rubocop(result[:stdout] || '')
            result.merge(parsed: parsed)
          end
        end
      end
    end
  end
end
