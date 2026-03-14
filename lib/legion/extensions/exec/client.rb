# frozen_string_literal: true

module Legion
  module Extensions
    module Exec
      class Client
        def initialize(base_path: Dir.pwd)
          @base_path = base_path
        end

        # Shell delegation
        def execute(command:, cwd: @base_path, **)
          Runners::Shell.execute(command: command, cwd: cwd, **)
        end

        def audit(**)
          Runners::Shell.audit(**)
        end

        # Git delegation
        def init(path: @base_path, **)
          Runners::Git.init(path: path)
        end

        def add(path: @base_path, **)
          Runners::Git.add(path: path, **)
        end

        def commit(path: @base_path, **)
          Runners::Git.commit(path: path, **)
        end

        def push(path: @base_path, **)
          Runners::Git.push(path: path, **)
        end

        def status(path: @base_path, **)
          Runners::Git.status(path: path)
        end

        def create_repo(**)
          Runners::Git.create_repo(**)
        end

        # Bundler delegation
        def install(path: @base_path, **)
          Runners::Bundler.install(path: path)
        end

        def exec_rspec(path: @base_path, **)
          Runners::Bundler.exec_rspec(path: path, **)
        end

        def exec_rubocop(path: @base_path, **)
          Runners::Bundler.exec_rubocop(path: path, **)
        end
      end
    end
  end
end
