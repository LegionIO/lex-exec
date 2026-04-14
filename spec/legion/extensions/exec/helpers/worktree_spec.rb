# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'open3'
require 'legion/extensions/exec/helpers/worktree'

RSpec.describe Legion::Extensions::Exec::Helpers::Worktree do
  let(:tmpdir) { Dir.mktmpdir('legion-worktree-test') }
  let(:worktree_base) { File.join(tmpdir, '.legion-worktrees') }

  before do
    Dir.chdir(tmpdir) do
      Open3.capture3('git', 'init')
      Open3.capture3('git', 'config', 'user.email', 'test@example.com')
      Open3.capture3('git', 'config', 'user.name', 'Test')
      File.write('README.md', '# Test')
      Open3.capture3('git', 'add', '.')
      Open3.capture3('git', 'commit', '-m', 'initial')
    end
    allow(described_class).to receive(:worktree_path) { |task_id| File.join(worktree_base, task_id.to_s) }
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe '.create' do
    it 'creates a git worktree' do
      Dir.chdir(tmpdir) do
        result = described_class.create(task_id: 'task-1')
        expect(result[:success]).to be true
        expect(result[:path]).to include('task-1')
        expect(Dir.exist?(result[:path])).to be true
      end
    end

    it 'returns error if worktree already exists' do
      Dir.chdir(tmpdir) do
        described_class.create(task_id: 'task-2')
        result = described_class.create(task_id: 'task-2')
        expect(result[:success]).to be false
        expect(result[:reason]).to eq(:already_exists)
      end
    end
  end

  describe '.remove' do
    it 'removes a worktree' do
      Dir.chdir(tmpdir) do
        create_result = described_class.create(task_id: 'task-3')
        result = described_class.remove(task_id: 'task-3')
        expect(result[:success]).to be true
        expect(Dir.exist?(create_result[:path])).to be false
      end
    end

    it 'returns not_found for missing worktree' do
      result = described_class.remove(task_id: 'nonexistent')
      expect(result[:success]).to be false
      expect(result[:reason]).to eq(:not_found)
    end
  end

  describe '.list' do
    it 'lists worktrees' do
      Dir.chdir(tmpdir) do
        described_class.create(task_id: 'task-4')
        result = described_class.list
        expect(result[:success]).to be true
        expect(result[:worktrees].size).to be >= 2
      end
    end
  end

  describe 'repo_path support' do
    let(:mock_worktree_path) { '/tmp/test-worktrees/123' }
    let(:repo_path) { '/tmp/repos/my-repo' }
    let(:status_double) { instance_double(Process::Status, success?: true) }

    before do
      allow(described_class).to receive(:worktree_path).with('123').and_return(mock_worktree_path)
      allow(Dir).to receive(:exist?).and_call_original
      allow(Dir).to receive(:exist?).with(mock_worktree_path).and_return(false)
      allow(FileUtils).to receive(:mkdir_p)
      allow(Open3).to receive(:capture3).and_return(['', '', status_double])
    end

    describe '.create with repo_path' do
      it 'passes chdir to Open3.capture3' do
        described_class.create(task_id: '123', repo_path: repo_path)
        expect(Open3).to have_received(:capture3).with(
          'git', 'worktree', 'add', mock_worktree_path, '-b', 'legion/123', 'HEAD',
          chdir: repo_path
        )
      end

      it 'returns success with path and branch' do
        result = described_class.create(task_id: '123', repo_path: repo_path)
        expect(result[:success]).to be true
        expect(result[:branch]).to eq('legion/123')
      end

      it 'does not pass chdir when repo_path is absent' do
        described_class.create(task_id: '123')
        expect(Open3).to have_received(:capture3).with(
          'git', 'worktree', 'add', mock_worktree_path, '-b', 'legion/123', 'HEAD'
        )
      end

      it 'uses the provided branch and base_ref' do
        described_class.create(task_id: '123', branch: 'fleet/fix-42', base_ref: 'origin/main', repo_path: repo_path)
        expect(Open3).to have_received(:capture3).with(
          'git', 'worktree', 'add', mock_worktree_path, '-b', 'fleet/fix-42', 'origin/main',
          chdir: repo_path
        )
      end
    end

    describe '.remove with repo_path' do
      before do
        allow(Dir).to receive(:exist?).with(mock_worktree_path).and_return(true)
      end

      it 'passes chdir to Open3.capture3' do
        described_class.remove(task_id: '123', repo_path: repo_path)
        expect(Open3).to have_received(:capture3).with(
          'git', 'worktree', 'remove', mock_worktree_path, '--force',
          chdir: repo_path
        )
      end

      it 'does not pass chdir when repo_path is absent' do
        described_class.remove(task_id: '123')
        expect(Open3).to have_received(:capture3).with(
          'git', 'worktree', 'remove', mock_worktree_path, '--force'
        )
      end
    end

    describe '.list with repo_path' do
      before do
        allow(Open3).to receive(:capture3).and_return(
          ["worktree /tmp/main\nbranch refs/heads/main\n\nworktree /tmp/wt\nbranch refs/heads/legion/123\n",
           '', status_double]
        )
      end

      it 'passes chdir to Open3.capture3' do
        described_class.list(repo_path: repo_path)
        expect(Open3).to have_received(:capture3).with(
          'git', 'worktree', 'list', '--porcelain',
          chdir: repo_path
        )
      end

      it 'does not pass chdir when repo_path is absent' do
        described_class.list
        expect(Open3).to have_received(:capture3).with(
          'git', 'worktree', 'list', '--porcelain'
        )
      end
    end
  end
end
