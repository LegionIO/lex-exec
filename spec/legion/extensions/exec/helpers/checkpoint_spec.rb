# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'open3'
require 'legion/extensions/exec/helpers/checkpoint'

RSpec.describe Legion::Extensions::Exec::Helpers::Checkpoint do
  let(:tmpdir) { Dir.mktmpdir('legion-checkpoint-test') }
  let(:task_id) { 'test-task' }

  before do
    Dir.chdir(tmpdir) do
      Open3.capture3('git', 'init')
      Open3.capture3('git', 'config', 'user.email', 'test@example.com')
      Open3.capture3('git', 'config', 'user.name', 'Test')
      File.write('file.txt', 'original')
      Open3.capture3('git', 'add', '.')
      Open3.capture3('git', 'commit', '-m', 'initial')
    end
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe '.save' do
    it 'creates a checkpoint ref' do
      File.write(File.join(tmpdir, 'file.txt'), 'modified')
      result = described_class.save(worktree_path: tmpdir, label: 'step-1', task_id: task_id)
      expect(result[:success]).to be true
      expect(result[:ref]).to eq("refs/checkpoints/#{task_id}/step-1")
    end
  end

  describe '.list_checkpoints' do
    it 'lists saved checkpoints' do
      Dir.chdir(tmpdir) do
        File.write('file.txt', 'v1')
        described_class.save(worktree_path: tmpdir, label: 'step-1', task_id: task_id)

        File.write('file.txt', 'v2')
        described_class.save(worktree_path: tmpdir, label: 'step-2', task_id: task_id)

        result = described_class.list_checkpoints(task_id: task_id)
        expect(result[:success]).to be true
        expect(result[:checkpoints].size).to eq(2)
      end
    end
  end

  describe '.restore' do
    it 'restores files to checkpoint state' do
      File.write(File.join(tmpdir, 'file.txt'), 'checkpoint-state')
      described_class.save(worktree_path: tmpdir, label: 'snap', task_id: task_id)

      File.write(File.join(tmpdir, 'file.txt'), 'later-state')

      result = described_class.restore(worktree_path: tmpdir, label: 'snap', task_id: task_id)
      expect(result[:success]).to be true
      expect(File.read(File.join(tmpdir, 'file.txt'))).to eq('checkpoint-state')
    end
  end

  describe '.prune' do
    it 'removes all checkpoint refs for a task' do
      Dir.chdir(tmpdir) do
        described_class.save(worktree_path: tmpdir, label: 'a', task_id: task_id)
        described_class.save(worktree_path: tmpdir, label: 'b', task_id: task_id)

        result = described_class.prune(task_id: task_id)
        expect(result[:success]).to be true
        expect(result[:pruned]).to eq(2)

        list = described_class.list_checkpoints(task_id: task_id)
        expect(list[:checkpoints]).to be_empty
      end
    end
  end
end
