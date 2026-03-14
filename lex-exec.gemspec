# frozen_string_literal: true

require_relative 'lib/legion/extensions/exec/version'

Gem::Specification.new do |spec|
  spec.name                  = 'lex-exec'
  spec.version               = Legion::Extensions::Exec::VERSION
  spec.authors               = ['Esity']
  spec.email                 = ['matthewdiverson@gmail.com']

  spec.summary               = 'LEX::Exec'
  spec.description           = 'Safe sandboxed shell execution for LegionIO'
  spec.homepage              = 'https://github.com/LegionIO/lex-exec'
  spec.license               = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.metadata['homepage_uri']        = spec.homepage
  spec.metadata['source_code_uri']     = 'https://github.com/LegionIO/lex-exec'
  spec.metadata['documentation_uri'] = 'https://github.com/LegionIO/lex-exec'
  spec.metadata['changelog_uri']       = 'https://github.com/LegionIO/lex-exec'
  spec.metadata['bug_tracker_uri']     = 'https://github.com/LegionIO/lex-exec/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.require_paths = ['lib']
end
