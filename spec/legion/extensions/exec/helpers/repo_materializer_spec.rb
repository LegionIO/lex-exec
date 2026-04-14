# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Exec::Helpers::RepoMaterializer do
  let(:work_item) do
    { task_id: 'task-abc', repo_url: 'https://github.com/LegionIO/lex-exec.git', branch: 'fleet/fix-42' }
  end
  let(:clone_success) { { success: true, stdout: '', stderr: '', exit_code: 0, duration_ms: 100, truncated: false } }
  let(:worktree_success) { { success: true, path: '/tmp/legion-repos/task-abc/lex-exec/.worktrees/task-abc', branch: 'fleet/fix-42' } }

  before do
    allow(Legion::Settings).to receive(:dig).and_call_original
    allow(Legion::Settings).to receive(:dig).with(:fleet, :materialization, :strategy).and_return(nil)
    allow(Legion::Settings).to receive(:dig).with(:fleet, :git, :depth).and_return(nil)
    allow(Legion::Settings).to receive(:dig).with(:fleet, :workspace, :repo_base).and_return(nil)
    allow(Legion::Extensions::Exec::Runners::Git).to receive(:clone).and_return(clone_success)
    allow(Legion::Extensions::Exec::Helpers::Worktree).to receive(:create).and_return(worktree_success)
    allow(Legion::Extensions::Exec::Helpers::Worktree).to receive(:remove).and_return({ success: true })
  end

  describe '.materialize' do
    it 'clones the repo and creates a worktree' do
      described_class.materialize(work_item: work_item)
      expect(Legion::Extensions::Exec::Runners::Git).to have_received(:clone).with(
        url:   'https://github.com/LegionIO/lex-exec.git',
        path:  anything,
        depth: nil
      )
      expect(Legion::Extensions::Exec::Helpers::Worktree).to have_received(:create).with(
        hash_including(task_id: 'task-abc', branch: 'fleet/fix-42')
      )
    end

    it 'returns workspace_path and branch on success' do
      result = described_class.materialize(work_item: work_item)
      expect(result[:success]).to be true
      expect(result[:workspace_path]).to be_a(String)
      expect(result[:branch]).to eq('fleet/fix-42')
    end

    it 'applies credential_provider to the URL before cloning' do
      authenticator = ->(url) { url.sub('https://', 'https://token:abc@') }
      described_class.materialize(work_item: work_item, credential_provider: authenticator)
      expect(Legion::Extensions::Exec::Runners::Git).to have_received(:clone).with(
        url:   'https://token:abc@github.com/LegionIO/lex-exec.git',
        path:  anything,
        depth: nil
      )
    end

    it 'returns failure when clone fails' do
      allow(Legion::Extensions::Exec::Runners::Git).to receive(:clone)
        .and_return({ success: false, stderr: 'repo not found' })
      result = described_class.materialize(work_item: work_item)
      expect(result[:success]).to be false
    end

    it 'propagates reason and stderr from clone failure' do
      allow(Legion::Extensions::Exec::Runners::Git).to receive(:clone)
        .and_return({ success: false, error: :timeout, reason: :timeout, stderr: nil })
      result = described_class.materialize(work_item: work_item)
      expect(result[:success]).to be false
      expect(result[:reason]).to eq(:timeout)
      expect(result[:clone_result]).to be_a(Hash)
    end

    it 'raises when credential_provider returns nil' do
      bad_provider = ->(_url) {}
      expect { described_class.materialize(work_item: work_item, credential_provider: bad_provider) }
        .to raise_error(ArgumentError, /non-empty String/)
    end

    it 'passes depth from settings to clone' do
      allow(Legion::Settings).to receive(:dig).with(:fleet, :git, :depth).and_return(5)
      described_class.materialize(work_item: work_item)
      expect(Legion::Extensions::Exec::Runners::Git).to have_received(:clone).with(
        url:   anything,
        path:  anything,
        depth: 5
      )
    end

    it 'passes repo_path to worktree create' do
      described_class.materialize(work_item: work_item)
      expect(Legion::Extensions::Exec::Helpers::Worktree).to have_received(:create).with(
        hash_including(repo_path: anything)
      )
    end
  end

  describe '.release' do
    it 'removes the worktree for the given task with repo_path' do
      described_class.release(work_item: work_item)
      expect(Legion::Extensions::Exec::Helpers::Worktree).to have_received(:remove).with(
        task_id:   'task-abc',
        repo_path: anything
      )
    end

    it 'returns the worktree remove result' do
      result = described_class.release(work_item: work_item)
      expect(result[:success]).to be true
    end
  end
end
