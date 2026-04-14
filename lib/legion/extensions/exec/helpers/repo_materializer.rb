# frozen_string_literal: true

require 'fileutils'

module Legion
  module Extensions
    module Exec
      module Helpers
        module RepoMaterializer
          class << self
            def materialize(work_item:, credential_provider: nil)
              strategy = resolve_strategy
              case strategy
              when :clone
                materialize_via_clone(work_item: work_item, credential_provider: credential_provider)
              else
                { success: false, error: "Unknown strategy: #{strategy}" }
              end
            end

            def release(work_item:)
              repo_path = build_repo_path(work_item)
              Helpers::Worktree.remove(task_id: work_item[:task_id], repo_path: repo_path)
            end

            private

            def resolve_strategy
              raw = Legion::Settings.dig(:fleet, :materialization, :strategy) if defined?(Legion::Settings)
              (raw || :clone).to_sym
            end

            def materialize_via_clone(work_item:, credential_provider:)
              url = apply_credentials(work_item[:repo_url], credential_provider)
              depth = Legion::Settings.dig(:fleet, :git, :depth) if defined?(Legion::Settings)
              repo_path = build_repo_path(work_item)

              begin
                ::FileUtils.mkdir_p(::File.dirname(repo_path))
              rescue StandardError => e
                return { success: false, reason: :mkdir_failed, error: e.message }
              end

              clone_result = Runners::Git.clone(url: url, path: repo_path, depth: depth)
              unless clone_result[:success]
                return {
                  success:      false,
                  error:        clone_result[:stderr] || clone_result[:reason] || clone_result[:error],
                  reason:       clone_result[:reason],
                  stderr:       clone_result[:stderr],
                  clone_result: clone_result
                }
              end

              worktree_result = Helpers::Worktree.create(
                task_id:   work_item[:task_id],
                branch:    work_item[:branch],
                base_ref:  work_item[:base_ref] || 'HEAD',
                repo_path: repo_path
              )
              return { success: false, error: worktree_result[:message] } unless worktree_result[:success]

              { success: true, workspace_path: worktree_result[:path], branch: worktree_result[:branch], repo_path: repo_path }
            end

            def apply_credentials(url, credential_provider)
              return url unless credential_provider

              result = credential_provider.call(url)
              raise ArgumentError, 'credential_provider must return a non-empty String URL' unless result.is_a?(String) && !result.empty?

              result
            end

            def build_repo_path(work_item)
              base = (Legion::Settings.dig(:fleet, :workspace, :repo_base) if defined?(Legion::Settings))
              base ||= '/tmp/legion-repos'
              repo_name = ::File.basename(work_item[:repo_url], '.git')
              ::File.join(base, work_item[:task_id].to_s, repo_name)
            end
          end
        end
      end
    end
  end
end
