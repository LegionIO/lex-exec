# frozen_string_literal: true

module Legion
  module Extensions
    module Exec
      module Runners
        module Git
          module_function

          def init(path:, **)
            Runners::Shell.execute(command: 'git init', cwd: path)
          end

          def add(path:, files: '.', **)
            cmd = files == '.' ? 'git add -A' : "git add #{Array(files).join(' ')}"
            Runners::Shell.execute(command: cmd, cwd: path)
          end

          def commit(path:, message:, **)
            safe_msg = message.gsub("'", "\\'")
            Runners::Shell.execute(command: "git commit -m '#{safe_msg}'", cwd: path)
          end

          def push(path:, remote: 'origin', branch: 'main', set_upstream: false, **)
            cmd = set_upstream ? "git push -u #{remote} #{branch}" : 'git push'
            Runners::Shell.execute(command: cmd, cwd: path)
          end

          def status(path:, **)
            result = Runners::Shell.execute(command: 'git status --porcelain', cwd: path)
            return result unless result[:success]

            parsed = Helpers::ResultParser.parse_git_status(result[:stdout] || '')
            result.merge(parsed: parsed)
          end

          def create_repo(name:, org: 'LegionIO', description: '', public: true, **)
            visibility = public ? '--public' : '--private'
            Runners::Shell.execute(
              command: "gh repo create #{org}/#{name} #{visibility} --description '#{description}' --clone",
              cwd:     Dir.pwd
            )
          end
        end
      end
    end
  end
end
