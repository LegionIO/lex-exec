# lex-exec

Sandboxed shell execution extension for LegionIO. Runs shell commands, git operations, and bundler workflows with allowlist enforcement and an in-memory audit log. Used by agentic swarm pipelines (e.g., `lex-swarm-github`) to validate and publish generated extensions.

## Installation

Add to your `Gemfile`:

```ruby
gem 'lex-exec'
```

Or install directly:

```bash
gem install lex-exec
```

## Overview

`lex-exec` provides three runners:

- **Shell** - Execute arbitrary shell commands against an allowlist
- **Git** - Common git operations (init, add, commit, push, status, create_repo)
- **Bundler** - Run `bundle install`, `rspec`, and `rubocop` with structured output parsing

All shell execution goes through a `Sandbox` that checks the base command against an allowlist and rejects commands matching blocked patterns. Every execution is recorded in a thread-safe in-memory `AuditLog`.

## Allowlisted Commands

Only the following base commands are permitted:

```
bundle  git  gh  ruby  rspec  rubocop
ls  cat  mkdir  cp  mv  rm  touch  echo  wc  head  tail
```

Commands not in this list are rejected before execution with `success: false, error: :blocked`.

## Blocked Patterns

The following patterns are always rejected regardless of allowlist membership:

- `rm -rf /` (root deletion)
- `rm -rf ~` (home deletion)
- `rm -rf ..` (parent directory deletion)
- `sudo` (privilege escalation)
- `chmod 777` (world-writable permissions)
- `curl | sh` (pipe-to-shell download execution)
- Redirects to `/etc` or `/usr`

## Limits

| Parameter | Default | Maximum |
|-----------|---------|---------|
| Timeout | 120,000 ms | 600,000 ms (10 min) |
| Output size (stdout/stderr) | — | 1,048,576 bytes (1 MB) |
| Audit log entries | — | 1,000 (ring buffer) |

Output exceeding 1 MB is truncated; `truncated: true` is set in the result and recorded in the audit log.

## Usage

### Direct runner calls

```ruby
# Shell runner
result = Legion::Extensions::Exec::Runners::Shell.execute(
  command: 'bundle exec rspec',
  cwd:     '/path/to/project',
  timeout: 120_000
)
# => { success: true, stdout: "...", stderr: "...", exit_code: 0, duration_ms: 1234, truncated: false }

# Retrieve audit log
audit = Legion::Extensions::Exec::Runners::Shell.audit(limit: 50)
# => { success: true, entries: [...], stats: { total:, success:, failure:, avg_duration_ms: } }
```

### Client interface

`Legion::Extensions::Exec::Client` provides a unified interface delegating to all three runners:

```ruby
client = Legion::Extensions::Exec::Client.new(base_path: '/path/to/project')

# Shell
client.execute(command: 'ls -la')
client.audit(limit: 25)

# Git
client.init
client.add(files: ['lib/foo.rb', 'spec/foo_spec.rb'])
client.commit(message: 'add foo runner')
client.push(remote: 'origin', branch: 'main', set_upstream: true)
client.status
client.create_repo(name: 'lex-foo', org: 'LegionIO', description: 'foo extension', public: true)

# Bundler
client.install
client.exec_rspec(format: 'progress')
client.exec_rubocop(autocorrect: false)
```

### Git runner

```ruby
# Initialize a new repo
Legion::Extensions::Exec::Runners::Git.init(path: '/path/to/dir')

# Stage files
Legion::Extensions::Exec::Runners::Git.add(path: '/path/to/dir', files: '.')
Legion::Extensions::Exec::Runners::Git.add(path: '/path/to/dir', files: ['file1.rb', 'file2.rb'])

# Commit
Legion::Extensions::Exec::Runners::Git.commit(path: '/path/to/dir', message: 'initial commit')

# Push (set_upstream: true adds -u flag)
Legion::Extensions::Exec::Runners::Git.push(path: '/path/to/dir', remote: 'origin', branch: 'main', set_upstream: true)

# Status (parses --porcelain output into structured form)
Legion::Extensions::Exec::Runners::Git.status(path: '/path/to/dir')

# Create GitHub repo via gh CLI
Legion::Extensions::Exec::Runners::Git.create_repo(
  name:        'lex-myext',
  org:         'LegionIO',
  description: 'my extension',
  public:      true
)
```

### Bundler runner

```ruby
# Install dependencies (5 min timeout)
Legion::Extensions::Exec::Runners::Bundler.install(path: '/path/to/project')

# Run RSpec with parsed output
result = Legion::Extensions::Exec::Runners::Bundler.exec_rspec(path: '/path/to/project', format: 'progress')
# result[:parsed] => { examples:, failures:, pending:, passed: }

# Run RuboCop with parsed output
result = Legion::Extensions::Exec::Runners::Bundler.exec_rubocop(path: '/path/to/project')
# result[:parsed] => { offenses:, files_inspected: }

# Run RuboCop with autocorrect
Legion::Extensions::Exec::Runners::Bundler.exec_rubocop(path: '/path/to/project', autocorrect: true)
```

## Return Value Shape

All runners return a hash with at minimum:

```ruby
{
  success:     true | false,
  stdout:      "...",          # present on success
  stderr:      "...",          # present on success
  exit_code:   0,              # present on success
  duration_ms: 123,            # present on success
  truncated:   false           # true if stdout exceeded 1 MB
}
```

On failure:

```ruby
{ success: false, error: :blocked, reason: "command 'sudo' is not in the allowlist" }
{ success: false, error: :timeout, timeout_ms: 120_000 }
{ success: false, error: "invalid argument message" }
```

## Agentic Pipeline Integration

`lex-exec` is designed to work alongside `lex-codegen` in the agentic swarm pipeline:

```
lex-codegen (scaffold_extension)    # generates file tree from ERB templates
      |
      v
lex-exec (Bundler.install)          # installs gem dependencies
      |
      v
lex-exec (Bundler.exec_rspec)       # runs test suite, returns pass/fail counts
      |
      v
lex-exec (Bundler.exec_rubocop)     # lints code, returns offense count
      |
      v
lex-exec (Git.commit + Git.push)    # commits and pushes validated extension
```

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

Apache-2.0
