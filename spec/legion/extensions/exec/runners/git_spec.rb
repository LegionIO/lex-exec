# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Exec::Runners::Git do
  subject(:runner) { described_class }

  let(:success_result) { { success: true, stdout: '', stderr: '', exit_code: 0, duration_ms: 5, truncated: false } }
  let(:failure_result) { { success: false, stdout: '', stderr: 'error', exit_code: 1, duration_ms: 5, truncated: false } }

  before do
    allow(Legion::Extensions::Exec::Runners::Shell).to receive(:execute).and_return(success_result)
  end

  describe '.init' do
    it 'runs git init in the given path' do
      runner.init(path: '/tmp/myrepo')
      expect(Legion::Extensions::Exec::Runners::Shell).to have_received(:execute)
        .with(command: 'git init', cwd: '/tmp/myrepo')
    end

    it 'returns the shell result' do
      result = runner.init(path: '/tmp/myrepo')
      expect(result[:success]).to be true
    end
  end

  describe '.add' do
    it 'runs git add -A when files is default' do
      runner.add(path: '/tmp/repo')
      expect(Legion::Extensions::Exec::Runners::Shell).to have_received(:execute)
        .with(command: 'git add -A', cwd: '/tmp/repo')
    end

    it 'runs git add with specific files' do
      runner.add(path: '/tmp/repo', files: 'lib/foo.rb')
      expect(Legion::Extensions::Exec::Runners::Shell).to have_received(:execute)
        .with(command: 'git add lib/foo.rb', cwd: '/tmp/repo')
    end

    it 'joins array of files' do
      runner.add(path: '/tmp/repo', files: ['lib/a.rb', 'lib/b.rb'])
      expect(Legion::Extensions::Exec::Runners::Shell).to have_received(:execute)
        .with(command: 'git add lib/a.rb lib/b.rb', cwd: '/tmp/repo')
    end
  end

  describe '.commit' do
    it 'runs git commit with the message' do
      runner.commit(path: '/tmp/repo', message: 'add feature')
      expect(Legion::Extensions::Exec::Runners::Shell).to have_received(:execute)
        .with(command: "git commit -m 'add feature'", cwd: '/tmp/repo')
    end

    it 'escapes single quotes in the message' do
      runner.commit(path: '/tmp/repo', message: "fix it's broken")
      expect(Legion::Extensions::Exec::Runners::Shell).to have_received(:execute) do |args|
        expect(args[:command]).to include('fix it')
      end
    end
  end

  describe '.push' do
    it 'runs git push with no arguments by default' do
      runner.push(path: '/tmp/repo')
      expect(Legion::Extensions::Exec::Runners::Shell).to have_received(:execute)
        .with(command: 'git push', cwd: '/tmp/repo')
    end

    it 'runs git push -u when set_upstream is true' do
      runner.push(path: '/tmp/repo', remote: 'origin', branch: 'main', set_upstream: true)
      expect(Legion::Extensions::Exec::Runners::Shell).to have_received(:execute)
        .with(command: 'git push -u origin main', cwd: '/tmp/repo')
    end
  end

  describe '.status' do
    context 'when git status succeeds' do
      let(:status_result) do
        success_result.merge(stdout: " M lib/foo.rb\n?? new.rb\n")
      end

      before do
        allow(Legion::Extensions::Exec::Runners::Shell).to receive(:execute).and_return(status_result)
      end

      it 'runs git status --porcelain' do
        runner.status(path: '/tmp/repo')
        expect(Legion::Extensions::Exec::Runners::Shell).to have_received(:execute)
          .with(command: 'git status --porcelain', cwd: '/tmp/repo')
      end

      it 'merges parsed git status' do
        result = runner.status(path: '/tmp/repo')
        expect(result[:parsed]).to be_a(Hash)
        expect(result[:parsed]).to have_key(:clean)
        expect(result[:parsed]).to have_key(:modified)
        expect(result[:parsed]).to have_key(:untracked)
      end

      it 'identifies modified files' do
        result = runner.status(path: '/tmp/repo')
        expect(result[:parsed][:modified]).to include('lib/foo.rb')
      end

      it 'identifies untracked files' do
        result = runner.status(path: '/tmp/repo')
        expect(result[:parsed][:untracked]).to include('new.rb')
      end
    end

    context 'when git status fails' do
      before do
        allow(Legion::Extensions::Exec::Runners::Shell).to receive(:execute).and_return(failure_result)
      end

      it 'returns the raw failure result without parsed key' do
        result = runner.status(path: '/tmp/repo')
        expect(result[:parsed]).to be_nil
        expect(result[:success]).to be false
      end
    end
  end

  describe '.create_repo' do
    it 'calls gh repo create with public flag by default' do
      runner.create_repo(name: 'myext')
      expect(Legion::Extensions::Exec::Runners::Shell).to have_received(:execute) do |args|
        expect(args[:command]).to include('gh repo create LegionIO/myext --public')
      end
    end

    it 'uses --private flag when public is false' do
      runner.create_repo(name: 'myext', public: false)
      expect(Legion::Extensions::Exec::Runners::Shell).to have_received(:execute) do |args|
        expect(args[:command]).to include('--private')
      end
    end

    it 'uses custom org' do
      runner.create_repo(name: 'myext', org: 'MyOrg')
      expect(Legion::Extensions::Exec::Runners::Shell).to have_received(:execute) do |args|
        expect(args[:command]).to include('MyOrg/myext')
      end
    end

    it 'includes description' do
      runner.create_repo(name: 'myext', description: 'my description')
      expect(Legion::Extensions::Exec::Runners::Shell).to have_received(:execute) do |args|
        expect(args[:command]).to include('my description')
      end
    end
  end
end
