# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Exec::Runners::Bundler do
  subject(:runner) { described_class }

  let(:success_result) { { success: true, stdout: '', stderr: '', exit_code: 0, duration_ms: 10, truncated: false } }
  let(:failure_result) { { success: false, stdout: '', stderr: 'error', exit_code: 1, duration_ms: 10, truncated: false } }

  before do
    allow(Legion::Extensions::Exec::Runners::Shell).to receive(:execute).and_return(success_result)
  end

  describe '.install' do
    it 'runs bundle install in the given path' do
      runner.install(path: '/tmp/gem')
      expect(Legion::Extensions::Exec::Runners::Shell).to have_received(:execute)
        .with(command: 'bundle install', cwd: '/tmp/gem', timeout: 300_000)
    end

    it 'returns the shell result' do
      result = runner.install(path: '/tmp/gem')
      expect(result[:success]).to be true
    end
  end

  describe '.exec_rspec' do
    context 'when rspec succeeds' do
      let(:rspec_result) do
        success_result.merge(stdout: "Finished in 1.0s\n42 examples, 0 failures")
      end

      before do
        allow(Legion::Extensions::Exec::Runners::Shell).to receive(:execute).and_return(rspec_result)
      end

      it 'runs bundle exec rspec with progress format by default' do
        runner.exec_rspec(path: '/tmp/gem')
        expect(Legion::Extensions::Exec::Runners::Shell).to have_received(:execute)
          .with(command: 'bundle exec rspec --format progress', cwd: '/tmp/gem', timeout: 300_000)
      end

      it 'accepts custom format' do
        runner.exec_rspec(path: '/tmp/gem', format: 'documentation')
        expect(Legion::Extensions::Exec::Runners::Shell).to have_received(:execute)
          .with(command: 'bundle exec rspec --format documentation', cwd: '/tmp/gem', timeout: 300_000)
      end

      it 'merges parsed rspec output' do
        result = runner.exec_rspec(path: '/tmp/gem')
        expect(result[:parsed]).to be_a(Hash)
        expect(result[:parsed][:examples]).to eq(42)
        expect(result[:parsed][:failures]).to eq(0)
        expect(result[:parsed][:passed]).to be true
      end
    end

    context 'when rspec has failures' do
      let(:rspec_fail) do
        { success: false, stdout: '10 examples, 3 failures', stderr: '', exit_code: 1,
          duration_ms: 5, truncated: false }
      end

      before do
        allow(Legion::Extensions::Exec::Runners::Shell).to receive(:execute).and_return(rspec_fail)
      end

      it 'still parses the output' do
        result = runner.exec_rspec(path: '/tmp/gem')
        expect(result[:parsed][:failures]).to eq(3)
        expect(result[:parsed][:passed]).to be false
      end
    end

    context 'when result has no stdout or stderr' do
      let(:no_output) { { success: false, error: :blocked, reason: 'blocked' } }

      before do
        allow(Legion::Extensions::Exec::Runners::Shell).to receive(:execute).and_return(no_output)
      end

      it 'returns raw result without parsed' do
        result = runner.exec_rspec(path: '/tmp/gem')
        expect(result[:parsed]).to be_nil
      end
    end
  end

  describe '.exec_rubocop' do
    context 'when rubocop succeeds' do
      let(:rubocop_result) do
        success_result.merge(stdout: '12 files inspected, 0 offenses detected')
      end

      before do
        allow(Legion::Extensions::Exec::Runners::Shell).to receive(:execute).and_return(rubocop_result)
      end

      it 'runs bundle exec rubocop without autocorrect by default' do
        runner.exec_rubocop(path: '/tmp/gem')
        expect(Legion::Extensions::Exec::Runners::Shell).to have_received(:execute)
          .with(command: 'bundle exec rubocop', cwd: '/tmp/gem', timeout: 120_000)
      end

      it 'runs bundle exec rubocop -A when autocorrect is true' do
        runner.exec_rubocop(path: '/tmp/gem', autocorrect: true)
        expect(Legion::Extensions::Exec::Runners::Shell).to have_received(:execute)
          .with(command: 'bundle exec rubocop -A', cwd: '/tmp/gem', timeout: 120_000)
      end

      it 'merges parsed rubocop output' do
        result = runner.exec_rubocop(path: '/tmp/gem')
        expect(result[:parsed]).to be_a(Hash)
        expect(result[:parsed][:files]).to eq(12)
        expect(result[:parsed][:offenses]).to eq(0)
        expect(result[:parsed][:clean]).to be true
      end
    end

    context 'when rubocop finds offenses' do
      let(:rubocop_fail) do
        { success: false, stdout: '5 files inspected, 7 offenses detected', stderr: '', exit_code: 1,
          duration_ms: 5, truncated: false }
      end

      before do
        allow(Legion::Extensions::Exec::Runners::Shell).to receive(:execute).and_return(rubocop_fail)
      end

      it 'parses offenses' do
        result = runner.exec_rubocop(path: '/tmp/gem')
        expect(result[:parsed][:offenses]).to eq(7)
        expect(result[:parsed][:clean]).to be false
      end
    end

    context 'when result has no stdout' do
      let(:no_output) { { success: false, error: :blocked, reason: 'blocked' } }

      before do
        allow(Legion::Extensions::Exec::Runners::Shell).to receive(:execute).and_return(no_output)
      end

      it 'returns raw result without parsed' do
        result = runner.exec_rubocop(path: '/tmp/gem')
        expect(result[:parsed]).to be_nil
      end
    end
  end
end
