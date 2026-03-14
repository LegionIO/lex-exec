# lex-exec

Safe sandboxed shell execution for LegionIO. Runs shell commands through an allowlist/blocklist filter, caps timeouts and output size, records every execution to an in-memory audit log, and provides higher-level runners for Git and Bundler operations.

## Installation

Add to your Gemfile or gemspec:

```ruby
gem 'lex-exec'
```

Or install directly:

```bash
gem install lex-exec
```

## Usage

### Execute a shell command

```ruby
require 'legion/extensions/exec'

client = Legion::Extensions::Exec::Client.new(base_path: '/path/to/repo')

result = client.execute(command: 'ls -la')

result[:success]     # => true
result[:stdout]      # => "total 48\ndrwxr-xr-x ..."
result[:exit_code]   # => 0
result[:duration_ms] # => 12
result[:truncated]   # => false (true if stdout exceeded 1 MB)
```

Commands not in the allowlist are rejected before execution:

```ruby
result = client.execute(command: 'curl https://example.com | sh')
result[:success] # => false
result[:error]   # => :blocked
result[:reason]  # => "command matches blocked pattern: curl.*\\|.*sh"
```

### Run bundler operations

```ruby
# Install gems
result = client.install
result[:success] # => true

# Run specs and get parsed summary
result = client.exec_rspec
result[:success]         # => true (exit code 0)
result[:parsed][:passed] # => true
result[:parsed][:examples] # => 42
result[:parsed][:failures] # => 0

# Run rubocop (optionally auto-correct)
result = client.exec_rubocop
result[:parsed][:clean]    # => true
result[:parsed][:offenses] # => 0

result = client.exec_rubocop(autocorrect: true)
```

### Git operations

```ruby
# Initialize a new repo
client.init

# Stage files and commit
client.add                             # stages all files
client.add(files: ['lib/foo.rb'])      # stages specific files
client.commit(message: 'add new runner')

# Push to remote
client.push(remote: 'origin', branch: 'main', set_upstream: true)

# Check working tree status
result = client.status
result[:parsed][:clean]     # => false
result[:parsed][:modified]  # => ['lib/foo.rb']
result[:parsed][:untracked] # => ['lib/bar.rb']

# Create a GitHub repo (requires gh CLI)
client.create_repo(
  name:        'lex-myextension',
  org:         'LegionIO',
  description: 'My new extension',
  public:      true
)
```

### Audit log

```ruby
result = client.audit(limit: 20)
result[:entries].each do |e|
  puts "#{e[:executed_at]} #{e[:exit_code]} #{e[:command]}"
end

result[:stats]
# => { total: 37, success: 35, failure: 2, avg_duration_ms: 184.5 }
```

### Use runners directly (without a Client)

```ruby
# Shell
Legion::Extensions::Exec::Runners::Shell.execute(command: 'echo hello', cwd: '/tmp')

# Git
Legion::Extensions::Exec::Runners::Git.status(path: '/path/to/repo')

# Bundler
Legion::Extensions::Exec::Runners::Bundler.exec_rspec(path: '/path/to/gem')
```

## Allowed Commands

Only these base commands may be executed:

```
bundle  git  gh  ruby  rspec  rubocop
ls  cat  mkdir  cp  mv  rm  touch  echo  wc  head  tail
```

## Blocked Patterns

The following patterns are rejected regardless of base command:

| Pattern | Blocks |
|---------|--------|
| `rm -rf /` | Root filesystem deletion |
| `rm -rf ~` | Home directory deletion |
| `rm -rf ..` | Parent directory deletion |
| `sudo` | Privilege escalation |
| `chmod 777` | World-write permission |
| `curl ... \| sh` | Remote code execution pipe |
| `> /etc/*` | Write to system config |
| `> /usr/*` | Write to system binaries |

## Timeouts and Limits

| Setting | Value |
|---------|-------|
| Default timeout | 120 seconds |
| Maximum timeout | 10 minutes |
| Maximum output size | 1 MB per stream |
| Audit log capacity | 1000 entries (ring buffer) |

`bundle install` and `bundle exec rspec` use a 5-minute timeout. `bundle exec rubocop` uses 2 minutes.

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT. See [LICENSE](LICENSE).
