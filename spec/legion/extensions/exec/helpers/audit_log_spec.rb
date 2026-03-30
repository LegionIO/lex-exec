# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Exec::Helpers::AuditLog do
  subject(:log) { described_class.new }

  def record_entry(overrides = {})
    defaults = { command: 'git status', cwd: '/tmp', exit_code: 0, duration_ms: 10 }
    log.record(**defaults, **overrides)
  end

  describe '#record' do
    it 'records a command entry' do
      record_entry
      expect(log.entries.size).to eq(1)
    end

    it 'stores all audit fields' do
      record_entry(command: 'git log', cwd: '/app', exit_code: 1, duration_ms: 42, truncated: true)
      entry = log.entries.first
      expect(entry[:command]).to eq('git log')
      expect(entry[:cwd]).to eq('/app')
      expect(entry[:exit_code]).to eq(1)
      expect(entry[:duration_ms]).to eq(42)
      expect(entry[:truncated]).to be true
    end

    it 'stores executed_at timestamp' do
      record_entry
      expect(log.entries.first[:executed_at]).to match(/\d{4}-\d{2}-\d{2}T/)
    end

    it 'defaults truncated to false' do
      record_entry
      expect(log.entries.first[:truncated]).to be false
    end

    it 'records multiple entries in order' do
      record_entry(command: 'git init')
      record_entry(command: 'git add -A')
      record_entry(command: 'git commit -m test')

      cmds = log.entries.map { |e| e[:command] }
      expect(cmds).to eq(['git init', 'git add -A', 'git commit -m test'])
    end

    it 'prunes oldest entries when MAX_ENTRIES is exceeded' do
      stub_const('Legion::Extensions::Exec::Helpers::AuditLog::MAX_ENTRIES', 3)
      record_entry(command: 'cmd1')
      record_entry(command: 'cmd2')
      record_entry(command: 'cmd3')
      record_entry(command: 'cmd4')

      entries = log.entries(limit: 10)
      expect(entries.size).to eq(3)
      expect(entries.map { |e| e[:command] }).not_to include('cmd1')
      expect(entries.map { |e| e[:command] }).to include('cmd4')
    end
  end

  describe '#entries' do
    it 'returns empty array when no entries' do
      expect(log.entries).to eq([])
    end

    it 'returns up to limit entries' do
      5.times { record_entry }
      expect(log.entries(limit: 3).size).to eq(3)
    end

    it 'returns most recent entries when limiting' do
      record_entry(command: 'first')
      record_entry(command: 'second')
      record_entry(command: 'third')

      result = log.entries(limit: 2)
      expect(result.map { |e| e[:command] }).to eq(%w[second third])
    end

    it 'defaults limit to 50' do
      60.times { record_entry }
      expect(log.entries.size).to eq(50)
    end
  end

  describe '#stats' do
    it 'returns zeros for empty log' do
      stats = log.stats
      expect(stats[:total]).to eq(0)
      expect(stats[:success]).to eq(0)
      expect(stats[:failure]).to eq(0)
      expect(stats[:avg_duration_ms]).to eq(0)
    end

    it 'counts total entries' do
      3.times { record_entry }
      expect(log.stats[:total]).to eq(3)
    end

    it 'counts successes (exit_code 0)' do
      record_entry(exit_code: 0)
      record_entry(exit_code: 0)
      record_entry(exit_code: 1)
      expect(log.stats[:success]).to eq(2)
    end

    it 'counts failures (non-zero exit_code)' do
      record_entry(exit_code: 0)
      record_entry(exit_code: 1)
      record_entry(exit_code: 127)
      expect(log.stats[:failure]).to eq(2)
    end

    it 'calculates average duration' do
      record_entry(duration_ms: 100)
      record_entry(duration_ms: 200)
      expect(log.stats[:avg_duration_ms]).to eq(150.0)
    end
  end

  describe '#clear' do
    it 'removes all entries' do
      3.times { record_entry }
      log.clear
      expect(log.entries).to be_empty
    end

    it 'resets stats to zero' do
      3.times { record_entry }
      log.clear
      expect(log.stats[:total]).to eq(0)
    end
  end

  describe 'thread safety' do
    it 'handles concurrent writes without data corruption' do
      threads = Array.new(10) do |i|
        Thread.new { record_entry(command: "cmd_#{i}") }
      end
      threads.each(&:join)
      expect(log.entries(limit: 100).size).to eq(10)
    end
  end
end
