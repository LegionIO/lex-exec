# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Exec::Runners::Shell do
  subject(:runner) { described_class }

  def make_status(exit_code)
    instance_double(Process::Status, exitstatus: exit_code)
  end

  describe '.execute' do
    context 'when the command is allowed' do
      it 'returns success: true for exit code 0' do
        allow(Open3).to receive(:capture3).and_return(["output\n", '', make_status(0)])
        result = runner.execute(command: 'git status', cwd: '/tmp')
        expect(result[:success]).to be true
        expect(result[:stdout]).to eq("output\n")
        expect(result[:exit_code]).to eq(0)
      end

      it 'returns success: false for non-zero exit code' do
        allow(Open3).to receive(:capture3).and_return(['', "error\n", make_status(1)])
        result = runner.execute(command: 'git status', cwd: '/tmp')
        expect(result[:success]).to be false
        expect(result[:exit_code]).to eq(1)
        expect(result[:stderr]).to eq("error\n")
      end

      it 'returns duration_ms as an integer' do
        allow(Open3).to receive(:capture3).and_return(['', '', make_status(0)])
        result = runner.execute(command: 'git log', cwd: '/tmp')
        expect(result[:duration_ms]).to be_a(Integer)
        expect(result[:duration_ms]).to be >= 0
      end

      it 'sets truncated: false for normal output' do
        allow(Open3).to receive(:capture3).and_return(['small output', '', make_status(0)])
        result = runner.execute(command: 'ls', cwd: '/tmp')
        expect(result[:truncated]).to be false
      end

      it 'truncates stdout over MAX_OUTPUT_BYTES' do
        large_output = 'x' * (Legion::Extensions::Exec::Helpers::Constants::MAX_OUTPUT_BYTES + 100)
        allow(Open3).to receive(:capture3).and_return([large_output, '', make_status(0)])
        result = runner.execute(command: 'cat', cwd: '/tmp')
        expect(result[:truncated]).to be true
        expect(result[:stdout].bytesize).to eq(Legion::Extensions::Exec::Helpers::Constants::MAX_OUTPUT_BYTES)
      end

      it 'passes the env hash to Open3' do
        allow(Open3).to receive(:capture3).and_return(['', '', make_status(0)])
        runner.execute(command: 'ruby -e "puts 1"', cwd: '/tmp', env: { 'FOO' => 'bar' })
        expect(Open3).to have_received(:capture3).with({ 'FOO' => 'bar' }, 'ruby -e "puts 1"', chdir: '/tmp')
      end

      it 'passes chdir to Open3' do
        allow(Open3).to receive(:capture3).and_return(['', '', make_status(0)])
        runner.execute(command: 'ls', cwd: '/var/tmp')
        expect(Open3).to have_received(:capture3).with({}, 'ls', chdir: '/var/tmp')
      end

      it 'records entry in audit log' do
        allow(Open3).to receive(:capture3).and_return(['out', '', make_status(0)])
        runner.execute(command: 'git status', cwd: '/tmp')
        audit = runner.audit
        expect(audit[:success]).to be true
        expect(audit[:stats][:total]).to be >= 1
      end
    end

    context 'when the command is blocked' do
      it 'returns blocked error without calling Open3' do
        allow(Open3).to receive(:capture3)
        result = runner.execute(command: 'curl https://evil.com', cwd: '/tmp')
        expect(result[:success]).to be false
        expect(result[:error]).to eq(:blocked)
        expect(result[:reason]).to be_a(String)
        expect(Open3).not_to have_received(:capture3)
      end

      it 'blocks rm -rf /' do
        allow(Open3).to receive(:capture3)
        result = runner.execute(command: 'rm -rf /', cwd: '/tmp')
        expect(result[:success]).to be false
        expect(result[:error]).to eq(:blocked)
        expect(Open3).not_to have_received(:capture3)
      end
    end

    context 'when timeout occurs' do
      it 'returns timeout error' do
        allow(Open3).to receive(:capture3).and_raise(Timeout::Error)
        result = runner.execute(command: 'git log', cwd: '/tmp', timeout: 1)
        expect(result[:success]).to be false
        expect(result[:error]).to eq(:timeout)
        expect(result[:timeout_ms]).to eq(1)
      end
    end

    context 'when an ArgumentError is raised' do
      it 'returns error with message' do
        allow(Open3).to receive(:capture3).and_raise(ArgumentError, 'bad argument')
        result = runner.execute(command: 'ruby -e "puts 1"', cwd: '/tmp')
        expect(result[:success]).to be false
        expect(result[:error]).to eq('bad argument')
      end
    end

    context 'with timeout capping' do
      it 'caps timeout at MAX_TIMEOUT' do
        allow(Open3).to receive(:capture3).and_return(['', '', make_status(0)])
        allow(Timeout).to receive(:timeout).and_call_original
        runner.execute(command: 'ls', cwd: '/tmp', timeout: 999_999_999)
        max_secs = Legion::Extensions::Exec::Helpers::Constants::MAX_TIMEOUT / 1000.0
        expect(Timeout).to have_received(:timeout).with(max_secs)
      end
    end
  end

  describe 'python venv rewriting' do
    let(:venv_dir) { Legion::Extensions::Exec::Helpers::Constants::LEGION_PYTHON_VENV }
    let(:venv_python) { "#{venv_dir}/bin/python3" }

    context 'when the venv exists' do
      before do
        allow(Legion::Extensions::Exec::Helpers::Constants).to receive(:venv_exists?).and_return(true)
        allow(Legion::Extensions::Exec::Helpers::Constants).to receive(:venv_python).and_return(venv_python)
        allow(Legion::Extensions::Exec::Helpers::Constants).to receive(:venv_pip).and_return("#{venv_dir}/bin/pip")
      end

      it 'rewrites python3 to venv path' do
        allow(Open3).to receive(:capture3).and_return(['', '', make_status(0)])
        runner.execute(command: 'python3 script.py', cwd: '/tmp')
        expect(Open3).to have_received(:capture3).with({}, "#{venv_python} script.py", chdir: '/tmp')
      end

      it 'rewrites pip3 to venv path' do
        allow(Open3).to receive(:capture3).and_return(['', '', make_status(0)])
        runner.execute(command: 'pip3 install requests', cwd: '/tmp')
        expect(Open3).to have_received(:capture3).with({}, "#{venv_dir}/bin/pip install requests", chdir: '/tmp')
      end

      it 'does not rewrite non-python commands' do
        allow(Open3).to receive(:capture3).and_return(['', '', make_status(0)])
        runner.execute(command: 'git status', cwd: '/tmp')
        expect(Open3).to have_received(:capture3).with({}, 'git status', chdir: '/tmp')
      end
    end

    context 'when the venv does not exist' do
      before do
        allow(Legion::Extensions::Exec::Helpers::Constants).to receive(:venv_exists?).and_return(false)
      end

      it 'leaves python3 commands unchanged' do
        allow(Open3).to receive(:capture3).and_return(['', '', make_status(0)])
        runner.execute(command: 'python3 script.py', cwd: '/tmp')
        expect(Open3).to have_received(:capture3).with({}, 'python3 script.py', chdir: '/tmp')
      end
    end
  end

  describe '.audit' do
    it 'returns success: true' do
      result = runner.audit
      expect(result[:success]).to be true
    end

    it 'returns entries array' do
      result = runner.audit
      expect(result[:entries]).to be_an(Array)
    end

    it 'returns stats hash' do
      result = runner.audit
      expect(result[:stats]).to be_a(Hash)
      expect(result[:stats]).to have_key(:total)
    end

    it 'respects limit parameter' do
      allow(Open3).to receive(:capture3).and_return(['', '', make_status(0)])
      5.times { runner.execute(command: 'ls', cwd: '/tmp') }
      result = runner.audit(limit: 2)
      expect(result[:entries].size).to be <= 2
    end
  end
end
