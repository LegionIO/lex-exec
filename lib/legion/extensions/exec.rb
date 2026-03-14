# frozen_string_literal: true

require 'securerandom'
require_relative 'exec/version'
require_relative 'exec/helpers/constants'
require_relative 'exec/helpers/sandbox'
require_relative 'exec/helpers/result_parser'
require_relative 'exec/helpers/audit_log'
require_relative 'exec/runners/shell'
require_relative 'exec/runners/git'
require_relative 'exec/runners/bundler'
require_relative 'exec/client'

module Legion
  module Extensions
    module Exec
      extend Legion::Extensions::Core if Legion::Extensions.const_defined? :Core
    end
  end
end
