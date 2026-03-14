# frozen_string_literal: true

require 'bundler/setup'
require 'legion/extensions/exec'

unless defined?(Legion::Logging)
  module Legion
    module Logging
      def self.info(*); end

      def self.debug(*); end

      def self.warn(*); end

      def self.error(*); end
    end
  end
end

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
