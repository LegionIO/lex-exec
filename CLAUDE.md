# lex-exec: Sandboxed Shell Execution for LegionIO

**Repository Level 3 Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-core/CLAUDE.md`
- **Grandparent**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

Legion Extension that provides sandboxed shell execution within a LegionIO cluster. Runs shell commands, git operations, and bundler workflows with allowlist enforcement and a thread-safe in-memory audit log. Used by agentic swarm pipelines (e.g., `lex-swarm-github`) to validate and publish generated extensions.

**GitHub**: https://github.com/LegionIO/lex-exec
**License**: Apache-2.0
**Version**: 0.1.1

## Architecture

```
Legion::Extensions::Exec
├── Runners/
│   ├── Shell     # execute, audit — allowlist + blocked pattern enforcement, Open3 subprocess
│   ├── Git       # init, add, commit, push, status, create_repo — git + gh CLI wrappers
│   └── Bundler   # install, exec_rspec, exec_rubocop — structured output parsing
├── Helpers/
│   ├── Sandbox      # allowlist check, blocked pattern check
│   ├── AuditLog     # thread-safe ring buffer (1000 entries max)
│   ├── ResultParser # parses RSpec and RuboCop stdout into structured hashes
│   └── Constants    # ALLOWED_COMMANDS array, BLOCKED_PATTERNS array
└── Client           # includes Shell + Git + Bundler; stores base_path
```

No explicit actors directory. The framework auto-generates subscription actors for each runner.

## Gem Info

| Field | Value |
|-------|-------|
| Gem name | `lex-exec` |
| Module | `Legion::Extensions::Exec` |
| Version | `0.1.1` |
| Ruby | `>= 3.4` |
| Runtime deps | `open3`, `timeout` (stdlib only) |
| License | Apache-2.0 |

## File Structure

```
lex-exec/
├── lex-exec.gemspec
├── Gemfile
├── lib/
│   └── legion/
│       └── extensions/
│           ├── exec.rb                        # Entry point; requires all helpers/runners/client
│           └── exec/
│               ├── version.rb
│               ├── client.rb                  # Client class; includes Shell + Git + Bundler
│               ├── helpers/
│               │   ├── sandbox.rb             # Allowlist + blocked pattern enforcement
│               │   ├── audit_log.rb           # Thread-safe ring buffer (1000 entries)
│               │   ├── result_parser.rb       # Parses RSpec/RuboCop stdout into structured hashes
│               │   └── constants.rb           # ALLOWED_COMMANDS and BLOCKED_PATTERNS
│               └── runners/
│                   ├── shell.rb               # execute, audit
│                   ├── git.rb                 # init, add, commit, push, status, create_repo
│                   └── bundler.rb             # install, exec_rspec, exec_rubocop
└── spec/
```

## Security Model

### Allowlisted Commands

Only the following base commands are permitted:

```
bundle  git  gh  ruby  rspec  rubocop
ls  cat  mkdir  cp  mv  rm  touch  echo  wc  head  tail
```

### Blocked Patterns

Always rejected regardless of allowlist:
- `rm -rf /` — root deletion
- `rm -rf ~` — home deletion
- `rm -rf ..` — parent directory deletion
- `sudo` — privilege escalation
- `chmod 777` — world-writable permissions
- `curl | sh` — pipe-to-shell download execution
- Redirects to `/etc` or `/usr`

### Limits

| Parameter | Default | Maximum |
|-----------|---------|---------|
| Timeout | 120,000 ms | 600,000 ms (10 min) |
| Output size (stdout + stderr) | — | 1,048,576 bytes (1 MB, truncated with flag) |
| Audit log entries | — | 1,000 (ring buffer, oldest evicted) |

## Runner Details

### Shell (`Runners::Shell`)

`extend self` — all methods callable on the module directly.

**`execute(command:, cwd: nil, timeout: 120_000, **)`**
- Validates command against allowlist and blocked patterns
- Runs with `Open3.capture3` under a `Timeout::timeout` guard
- Returns `{ success:, stdout:, stderr:, exit_code:, duration_ms:, truncated: }`
- On failure: `{ success: false, error: :blocked/:timeout/:exception }`

**`audit(limit: 100, **)`**
- Returns entries from the ring buffer
- Returns `{ success: true, entries: [], stats: { total:, success:, failure:, avg_duration_ms: } }`

### Git (`Runners::Git`)

`extend self`.

| Method | Notes |
|--------|-------|
| `init(path:)` | `git init` |
| `add(path:, files:)` | `git add` with string or array |
| `commit(path:, message:)` | `git commit -m` |
| `push(path:, remote: 'origin', branch: 'main', set_upstream: false)` | `-u` flag when `set_upstream: true` |
| `status(path:)` | Parses `--porcelain` output into structured form |
| `create_repo(name:, org:, description: '', public: true)` | `gh repo create --clone`; defaults branch to `main` |

### Bundler (`Runners::Bundler`)

`extend self`.

| Method | Notes |
|--------|-------|
| `install(path:)` | 5 min timeout |
| `exec_rspec(path:, format: 'progress')` | `result[:parsed]` => `{ examples:, failures:, pending:, passed: }` |
| `exec_rubocop(path:, autocorrect: false)` | `result[:parsed]` => `{ offenses:, files_inspected: }` |

## Client

`Client.new(base_path: '/path/to/project')` stores `@base_path`. All runner methods delegate to the corresponding `extend self` modules with `path: @base_path`.

## Integration Points

- **`lex-codegen`**: Natural companion. Codegen produces the file tree; exec runs `bundle install`, `bundle exec rspec`, `bundle exec rubocop`, then commits and pushes.
- **`lex-swarm-github`**: Swarm pipeline calls exec to validate and publish generated extensions.

## Testing

```bash
bundle install
bundle exec rspec     # 127 examples, 0 failures
bundle exec rubocop   # 0 offenses
```

Specs mock `Open3.capture3` and `Timeout::timeout` — no real shell commands execute in tests.

---

**Maintained By**: Matthew Iverson (@Esity)
