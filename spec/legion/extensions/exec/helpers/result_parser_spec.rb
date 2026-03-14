# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Exec::Helpers::ResultParser do
  describe '.parse_rspec' do
    it 'parses successful rspec output' do
      output = "Finished in 0.5 seconds\n42 examples, 0 failures"
      result = described_class.parse_rspec(output)
      expect(result[:examples]).to eq(42)
      expect(result[:failures]).to eq(0)
      expect(result[:passed]).to be true
    end

    it 'parses failing rspec output' do
      output = "Finished in 1.2 seconds\n10 examples, 3 failures"
      result = described_class.parse_rspec(output)
      expect(result[:examples]).to eq(10)
      expect(result[:failures]).to eq(3)
      expect(result[:passed]).to be false
    end

    it 'parses rspec output with pending' do
      output = '15 examples, 0 failures, 2 pending'
      result = described_class.parse_rspec(output)
      expect(result[:examples]).to eq(15)
      expect(result[:failures]).to eq(0)
      expect(result[:pending]).to eq(2)
      expect(result[:passed]).to be true
    end

    it 'handles singular example' do
      output = '1 example, 0 failures'
      result = described_class.parse_rspec(output)
      expect(result[:examples]).to eq(1)
      expect(result[:failures]).to eq(0)
    end

    it 'handles 1 failure' do
      output = '5 examples, 1 failure'
      result = described_class.parse_rspec(output)
      expect(result[:failures]).to eq(1)
      expect(result[:passed]).to be false
    end

    it 'returns zeros for unrecognized output' do
      result = described_class.parse_rspec('something went very wrong')
      expect(result[:examples]).to eq(0)
      expect(result[:failures]).to eq(0)
      expect(result[:pending]).to eq(0)
      expect(result[:passed]).to be true
    end

    it 'returns zero pending when not mentioned' do
      output = '5 examples, 0 failures'
      result = described_class.parse_rspec(output)
      expect(result[:pending]).to eq(0)
    end

    it 'handles empty string' do
      result = described_class.parse_rspec('')
      expect(result[:examples]).to eq(0)
      expect(result[:passed]).to be true
    end
  end

  describe '.parse_rubocop' do
    it 'parses clean rubocop output' do
      output = "Inspecting 12 files\n\n12 files inspected, 0 offenses detected"
      result = described_class.parse_rubocop(output)
      expect(result[:files]).to eq(12)
      expect(result[:offenses]).to eq(0)
      expect(result[:clean]).to be true
    end

    it 'parses rubocop output with offenses' do
      output = '5 files inspected, 7 offenses detected'
      result = described_class.parse_rubocop(output)
      expect(result[:files]).to eq(5)
      expect(result[:offenses]).to eq(7)
      expect(result[:clean]).to be false
    end

    it 'handles singular file and offense' do
      output = '1 file inspected, 1 offense detected'
      result = described_class.parse_rubocop(output)
      expect(result[:files]).to eq(1)
      expect(result[:offenses]).to eq(1)
      expect(result[:clean]).to be false
    end

    it 'returns zeros for unrecognized output' do
      result = described_class.parse_rubocop('rubocop crashed')
      expect(result[:files]).to eq(0)
      expect(result[:offenses]).to eq(0)
      expect(result[:clean]).to be true
    end

    it 'handles empty string' do
      result = described_class.parse_rubocop('')
      expect(result[:files]).to eq(0)
      expect(result[:clean]).to be true
    end
  end

  describe '.parse_git_status' do
    it 'returns clean for empty output' do
      result = described_class.parse_git_status('')
      expect(result[:clean]).to be true
      expect(result[:modified]).to be_empty
      expect(result[:untracked]).to be_empty
      expect(result[:deleted]).to be_empty
    end

    it 'parses modified files' do
      output = " M lib/foo.rb\n M lib/bar.rb"
      result = described_class.parse_git_status(output)
      expect(result[:modified]).to include('lib/foo.rb', 'lib/bar.rb')
      expect(result[:clean]).to be false
    end

    it 'parses untracked files' do
      output = "?? new_file.rb\n?? spec/new_spec.rb"
      result = described_class.parse_git_status(output)
      expect(result[:untracked]).to include('new_file.rb', 'spec/new_spec.rb')
      expect(result[:clean]).to be false
    end

    it 'parses deleted files' do
      output = ' D old_file.rb'
      result = described_class.parse_git_status(output)
      expect(result[:deleted]).to include('old_file.rb')
      expect(result[:clean]).to be false
    end

    it 'parses mixed status' do
      output = " M changed.rb\n?? new.rb\n D gone.rb"
      result = described_class.parse_git_status(output)
      expect(result[:modified]).not_to be_empty
      expect(result[:untracked]).not_to be_empty
      expect(result[:deleted]).not_to be_empty
      expect(result[:clean]).to be false
    end

    it 'marks clean when all arrays are empty' do
      result = described_class.parse_git_status("  \n")
      expect(result[:clean]).to be true
    end
  end
end
