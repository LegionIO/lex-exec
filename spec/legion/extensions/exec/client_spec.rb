# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Exec::Client do
  subject(:client) { described_class.new(base_path: '/tmp') }

  let(:success_result) do
    { success: true, stdout: '', stderr: '', exit_code: 0, duration_ms: 5, truncated: false }
  end

  before do
    allow(Legion::Extensions::Exec::Runners::Shell).to receive(:execute).and_return(success_result)
  end

  describe '#initialize' do
    it 'sets base_path' do
      c = described_class.new(base_path: '/app')
      expect(c.instance_variable_get(:@base_path)).to eq('/app')
    end

    it 'defaults base_path to Dir.pwd' do
      c = described_class.new
      expect(c.instance_variable_get(:@base_path)).to eq(Dir.pwd)
    end
  end

  describe 'Shell module inclusion' do
    it 'can call execute' do
      expect { client.execute(command: 'git status', cwd: '/tmp') }.not_to raise_error
    end

    it 'can call audit' do
      result = client.audit
      expect(result[:success]).to be true
    end
  end

  describe 'Git module inclusion' do
    it 'can call init' do
      expect { client.init(path: '/tmp/repo') }.not_to raise_error
    end

    it 'can call add' do
      expect { client.add(path: '/tmp/repo') }.not_to raise_error
    end

    it 'can call commit' do
      expect { client.commit(path: '/tmp/repo', message: 'test') }.not_to raise_error
    end

    it 'can call push' do
      expect { client.push(path: '/tmp/repo') }.not_to raise_error
    end

    it 'can call status' do
      allow(Legion::Extensions::Exec::Runners::Shell).to receive(:execute)
        .and_return(success_result.merge(stdout: ''))
      expect { client.status(path: '/tmp/repo') }.not_to raise_error
    end
  end

  describe 'Bundler module inclusion' do
    it 'can call install' do
      allow(Legion::Extensions::Exec::Runners::Shell).to receive(:execute).and_return(success_result)
      expect { client.install(path: '/tmp/gem') }.not_to raise_error
    end

    it 'can call exec_rspec' do
      allow(Legion::Extensions::Exec::Runners::Shell).to receive(:execute)
        .and_return(success_result.merge(stdout: '0 examples, 0 failures'))
      expect { client.exec_rspec(path: '/tmp/gem') }.not_to raise_error
    end

    it 'can call exec_rubocop' do
      allow(Legion::Extensions::Exec::Runners::Shell).to receive(:execute)
        .and_return(success_result.merge(stdout: '0 files inspected, 0 offenses detected'))
      expect { client.exec_rubocop(path: '/tmp/gem') }.not_to raise_error
    end
  end
end
