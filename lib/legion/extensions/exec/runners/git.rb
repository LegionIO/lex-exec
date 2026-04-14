# frozen_string_literal: true

module Legion
  module Extensions
    module Exec
      module Runners
        module Git # rubocop:disable Legion/Extension/RunnerIncludeHelpers
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
            return result unless result[:success] # rubocop:disable Legion/Extension/RunnerReturnHash

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

          def clone(url:, path:, depth: nil, branch: nil, **)
            resolved_depth = depth
            resolved_depth ||= Legion::Settings.dig(:fleet, :git, :depth) if defined?(Legion::Settings)
            args = ['git clone']
            args << "--depth #{resolved_depth}" if resolved_depth
            args << "--branch #{branch}" if branch
            args << url << path
            Runners::Shell.execute(command: args.join(' '), cwd: nil)
          end

          def fetch(path:, remote: nil, **)
            cmd = remote ? "git fetch #{remote} --prune" : 'git fetch --all --prune'
            Runners::Shell.execute(command: cmd, cwd: path)
          end

          def checkout(path:, ref:, create: false, **)
            flag = create ? ' -b' : ''
            Runners::Shell.execute(command: "git checkout#{flag} #{ref}", cwd: path)
          end
        end
      end
    end
  end
end
