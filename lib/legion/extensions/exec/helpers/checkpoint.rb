# frozen_string_literal: true

require 'open3'

module Legion
  module Extensions
    module Exec
      module Helpers
        module Checkpoint
          class << self
            def save(worktree_path:, label:, task_id:)
              Dir.chdir(worktree_path) do
                Open3.capture3('git', 'add', '-A')

                tree_sha, _err, tree_status = Open3.capture3('git', 'write-tree')
                return { success: false, reason: :write_tree_failed } unless tree_status.success?

                tree_sha = tree_sha.strip
                commit_sha, _err, commit_status = Open3.capture3(
                  'git', 'commit-tree', tree_sha, '-m', "checkpoint: #{label}"
                )
                return { success: false, reason: :commit_tree_failed } unless commit_status.success?

                commit_sha = commit_sha.strip
                ref = "refs/checkpoints/#{task_id}/#{label}"
                _out, _err, ref_status = Open3.capture3('git', 'update-ref', ref, commit_sha)
                return { success: false, reason: :update_ref_failed } unless ref_status.success?

                Open3.capture3('git', 'reset', 'HEAD')
                { success: true, ref: ref, commit: commit_sha }
              end
            end

            def restore(worktree_path:, label:, task_id:)
              ref = "refs/checkpoints/#{task_id}/#{label}"
              Dir.chdir(worktree_path) do
                _stdout, stderr, status = Open3.capture3('git', 'checkout', ref, '--', '.')
                status.success? ? { success: true, ref: ref } : { success: false, message: stderr.strip }
              end
            end

            def list_checkpoints(task_id:)
              pattern = "refs/checkpoints/#{task_id}/"
              stdout, = Open3.capture3('git', 'for-each-ref', '--format=%(refname) %(creatordate:iso8601)', pattern)
              checkpoints = stdout.strip.split("\n").filter_map do |line|
                next if line.strip.empty?

                parts = line.split(' ', 2)
                label = parts[0].sub(pattern, '')
                { label: label, created_at: parts[1] }
              end
              { success: true, checkpoints: checkpoints }
            end

            def prune(task_id:)
              pattern = "refs/checkpoints/#{task_id}/"
              stdout, = Open3.capture3('git', 'for-each-ref', '--format=%(refname)', pattern)
              refs = stdout.strip.split("\n").reject(&:empty?)
              refs.each { |ref| Open3.capture3('git', 'update-ref', '-d', ref) }
              { success: true, pruned: refs.size }
            end
          end
        end
      end
    end
  end
end
