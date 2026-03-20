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
end
