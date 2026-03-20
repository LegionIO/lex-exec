# frozen_string_literal: true

require 'open3'
require 'fileutils'

module Legion
  module Extensions
    module Exec
      module Helpers
        module Worktree
          class << self
            def create(task_id:, branch: nil, base_ref: 'HEAD')
              branch ||= "legion/#{task_id}"
              path = worktree_path(task_id)
              return { success: false, reason: :already_exists } if Dir.exist?(path)

              FileUtils.mkdir_p(File.dirname(path))
              _stdout, stderr, status = Open3.capture3('git', 'worktree', 'add', path, '-b', branch, base_ref)
              if status.success?
                { success: true, path: path, branch: branch }
              else
                { success: false, reason: :git_error, message: stderr.strip }
              end
            end

            def remove(task_id:)
              path = worktree_path(task_id)
              return { success: false, reason: :not_found } unless Dir.exist?(path)

              _stdout, stderr, status = Open3.capture3('git', 'worktree', 'remove', path, '--force')
              if status.success?
                { success: true }
              else
                { success: false, reason: :git_error, message: stderr.strip }
              end
            end

            def list
              stdout, _stderr, _status = Open3.capture3('git', 'worktree', 'list', '--porcelain')
              worktrees = parse_worktree_list(stdout)
              { success: true, worktrees: worktrees }
            end

            def worktree_path(task_id)
              base = Legion::Settings.dig(:worktree, :base_dir) if defined?(Legion::Settings)
              File.join(base || File.join(Dir.pwd, '.legion-worktrees'), task_id.to_s)
            end

            private

            def parse_worktree_list(output)
              output.split("\n\n").filter_map do |block|
                lines = block.strip.split("\n")
                next if lines.empty?

                path = lines.find { |l| l.start_with?('worktree ') }&.sub('worktree ', '')
                branch = lines.find { |l| l.start_with?('branch ') }&.sub('branch ', '')
                { path: path, branch: branch } if path
              end
            end
          end
        end
      end
    end
  end
end
