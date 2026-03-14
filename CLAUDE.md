# lex-exec: Safe Sandboxed Shell Execution for LegionIO

**Repository Level 3 Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-core/CLAUDE.md`
- **Grandparent**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

Legion Extension that provides safe, audited shell command execution. Enforces an allowlist of permitted commands, blocks dangerous patterns, caps timeouts and output size, and maintains an in-memory audit log of every execution. Provides higher-level runners for Git operations (init, add, commit, push, status, repo creation) and Bundler operations (install, rspec, rubocop) built on top of the core shell runner.

Used by agentic swarm pipelines (particularly `lex-swarm-github`) to run `bundle install`, `bundle exec rspec`, and `bundle exec rubocop` against newly generated or modified extension repos, and to perform Git operations.

**GitHub**: https://github.com/LegionIO/lex-exec
**License**: MIT
**Version**: 0.1.0

## Architecture

```
Legion::Extensions::Exec
├── Runners/
│   ├── Shell      # Core sandboxed executor (Open3 + Timeout); owns the audit log
│   ├── Git        # Git operations delegated through Shell
│   └── Bundler    # bundle install / rspec / rubocop delegated through Shell
├── Helpers/
│   ├── Constants  # Allowlist, block patterns, timeouts, output cap
│   ├── Sandbox    # Allowlist check + pattern match; returns { allowed:, reason: }
│   ├── ResultParser # Parses rspec/rubocop/git status output into structured hashes
│   └── AuditLog   # Thread-safe ring buffer; max 1000 entries
└── Client         # Thin facade; delegates to Shell/Git/Bundler, defaults cwd to base_path
```

No explicit actors directory. The framework auto-generates subscription actors for each runner.

## Gem Info

| Field | Value |
|-------|-------|
| Gem name | `lex-exec` |
| Module | `Legion::Extensions::Exec` |
| Version | `0.1.0` |
| Ruby | `>= 3.4` |
| Runtime deps | none declared (uses stdlib: `open3`, `timeout`, `securerandom`) |

## File Structure

```
lex-exec/
├── lex-exec.gemspec
├── Gemfile
├── lib/
│   └── legion/
│       └── extensions/
│           ├── exec.rb                          # Entry point; requires all helpers/runners/client
│           └── exec/
│               ├── version.rb
│               ├── client.rb                    # Client class; delegates to Shell/Git/Bundler
│               ├── helpers/
│               │   ├── constants.rb             # ALLOWED_COMMANDS, BLOCKED_PATTERNS, timeouts
│               │   ├── sandbox.rb               # Sandbox class; allowed? and sanitize
│               │   ├── result_parser.rb         # parse_rspec, parse_rubocop, parse_git_status
│               │   └── audit_log.rb             # AuditLog class; record, entries, stats, clear
│               └── runners/
│                   ├── shell.rb                 # execute, audit (owns Sandbox + AuditLog singletons)
│                   ├── git.rb                   # init, add, commit, push, status, create_repo
│                   └── bundler.rb               # install, exec_rspec, exec_rubocop
└── spec/
```

## Key Constants

Defined in `Helpers::Constants`:

| Constant | Value |
|----------|-------|
| `DEFAULT_TIMEOUT` | `120_000` ms (120 seconds) |
| `MAX_TIMEOUT` | `600_000` ms (10 minutes) |
| `MAX_OUTPUT_BYTES` | `1_048_576` (1 MB) |
| `ALLOWED_COMMANDS` | `bundle git gh ruby rspec rubocop ls cat mkdir cp mv rm touch echo wc head tail` |
| `BLOCKED_PATTERNS` | 8 regex patterns blocking `rm -rf /`, `rm -rf ~`, `sudo`, `chmod 777`, `curl | sh`, writes to `/etc` or `/usr` |
| `AUDIT_FIELDS` | `[:command, :cwd, :exit_code, :duration_ms, :executed_at, :truncated]` |

## Runners

### Shell (`Runners::Shell`)

`extend self` — callable on the module directly.
Owns two memoized singletons: `@default_sandbox` (a `Helpers::Sandbox` instance) and `@audit_log` (a `Helpers::AuditLog` instance).

**`execute(command:, cwd: Dir.pwd, timeout: DEFAULT_TIMEOUT, env: {}, **)`**
- Checks command against the sandbox; returns `{ success: false, error: :blocked, reason: }` if rejected
- Runs via `Open3.capture3` wrapped in `Timeout.timeout` (capped at `MAX_TIMEOUT`)
- Truncates stdout/stderr at `MAX_OUTPUT_BYTES`; sets `truncated: true` if stdout was cut
- Records to audit log on every execution
- Emits `Legion::Logging.debug` with exit code, duration, and command
- Returns:
  ```ruby
  { success:, stdout:, stderr:, exit_code:, duration_ms:, truncated: }
  ```
- Returns `{ success: false, error: :timeout, timeout_ms: }` on timeout
- Returns `{ success: false, error: <message> }` on `ArgumentError`

**`audit(limit: 50, **)`**
- Returns `{ success: true, entries: [], stats: {} }` from the in-memory audit log

### Git (`Runners::Git`)

`module_function` — callable on the module directly. All operations delegate to `Runners::Shell.execute`.

**`init(path:, **)`** — runs `git init` in `path`

**`add(path:, files: '.', **)`** — runs `git add -A` (all files) or `git add <file list>`

**`commit(path:, message:, **)`** — runs `git commit -m '...'`; single-quotes in message are escaped

**`push(path:, remote: 'origin', branch: 'master', set_upstream: false, **)`**
- `set_upstream: true` adds `-u remote branch` flags

**`status(path:, **)`**
- Runs `git status --porcelain`; on success, merges `Helpers::ResultParser.parse_git_status` result into the shell result under `:parsed` key

**`create_repo(name:, org: 'LegionIO', description: '', public: true, **)`**
- Runs `gh repo create <org>/<name> [--public|--private] --description '...' --clone`
- Requires `gh` CLI to be authenticated

### Bundler (`Runners::Bundler`)

`module_function` — callable on the module directly. All operations delegate to `Runners::Shell.execute`.

**`install(path:, **)`** — runs `bundle install` with a 300-second timeout

**`exec_rspec(path:, format: 'progress', **)`**
- Runs `bundle exec rspec --format <format>` with a 300-second timeout
- On success, merges `Helpers::ResultParser.parse_rspec` result under `:parsed` key
- Parsed result: `{ examples:, failures:, pending:, passed: }`

**`exec_rubocop(path:, autocorrect: false, **)`**
- Runs `bundle exec rubocop` or `bundle exec rubocop -A` with a 120-second timeout
- On success, merges `Helpers::ResultParser.parse_rubocop` result under `:parsed` key
- Parsed result: `{ files:, offenses:, clean: }`

## Helpers

### Sandbox

Class. Initialized with optional `allowed_commands:` and `blocked_patterns:` overrides; defaults to constants.

**`allowed?(command)`**
- Extracts the base command (first whitespace-delimited token)
- Returns `{ allowed: false, reason: }` if base command is not in allowlist
- Returns `{ allowed: false, reason: }` if the full command matches any blocked pattern
- Returns `{ allowed: true, reason: nil }` if both checks pass

**`sanitize(command)`**
- Strips backticks, `$`, and parentheses from the command string

### ResultParser

`module_function` — callable on the module directly.

**`parse_rspec(output)`**
- Extracts counts via regex from rspec summary line
- Returns `{ examples:, failures:, pending:, passed: }`

**`parse_rubocop(output)`**
- Extracts file count and offense count via regex from rubocop summary line
- Returns `{ files:, offenses:, clean: }`

**`parse_git_status(output)`**
- Parses `git status --porcelain` output line by line
- Status codes: `M`/`MM`/`AM` -> modified, `??` -> untracked, `D`/`MD` -> deleted
- Returns `{ clean:, modified: [], untracked: [], deleted: [] }`

### AuditLog

Class. Thread-safe via `Mutex`. Ring buffer capped at 1000 entries.

**`record(command:, cwd:, exit_code:, duration_ms:, truncated: false)`**
- Appends entry with `executed_at: Time.now.utc.iso8601`
- Drops oldest entries when size exceeds `MAX_ENTRIES`

**`entries(limit: 50)`** — returns the last `limit` entries

**`stats`** — returns `{ total:, success:, failure:, avg_duration_ms: }`

**`clear`** — empties the ring buffer

## Client

Class. Initialized with `base_path: Dir.pwd`. Provides a unified interface by delegating to all three runners, using `@base_path` as the default for any `path:`/`cwd:` argument.

| Client method | Delegates to |
|---------------|-------------|
| `execute(command:, cwd: @base_path, **)` | `Shell.execute` |
| `audit(**)` | `Shell.audit` |
| `init(path: @base_path, **)` | `Git.init` |
| `add(path: @base_path, **)` | `Git.add` |
| `commit(path: @base_path, **)` | `Git.commit` |
| `push(path: @base_path, **)` | `Git.push` |
| `status(path: @base_path, **)` | `Git.status` |
| `create_repo(**)` | `Git.create_repo` |
| `install(path: @base_path, **)` | `Bundler.install` |
| `exec_rspec(path: @base_path, **)` | `Bundler.exec_rspec` |
| `exec_rubocop(path: @base_path, **)` | `Bundler.exec_rubocop` |

## Integration Points

- **`lex-swarm-github`** uses lex-exec to run `bundle install`, `bundle exec rspec`, and `bundle exec rubocop` against repos under construction; also uses Git runners for `commit` and `push`
- **`lex-codegen`** is the natural companion: codegen produces files, exec validates and commits them
- Shell runner is the single chokepoint for all process execution — sandbox and audit log apply universally

## Development Notes

- `Runners::Shell` owns `@default_sandbox` and `@audit_log` as module-level memoized instances (`@default_sandbox ||= ...`). These persist for the lifetime of the process and are shared across all calls to the module
- Audit log is in-memory only; it does not persist across process restarts and is not written to `legion-data`
- `Sandbox#sanitize` is not called automatically by `execute` — callers must invoke it explicitly if needed; `execute` only calls `allowed?`
- `Bundler.exec_rspec` returns the shell result unchanged if both `stdout` and `stderr` are nil (no parsed rspec summary in that case)
- `Bundler.exec_rubocop` returns the shell result unchanged if `stdout` is nil
- Git `commit` escapes single quotes in the message with a backslash; does not handle all shell-unsafe characters
- `create_repo` defaults `branch` parameter named `branch` but git default branch is `master` — new repos created via `gh` default to `main`; callers should pass `branch: 'main'` explicitly
- The gemspec declares no runtime dependencies; `open3` and `timeout` are Ruby stdlib

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

---

**Maintained By**: Matthew Iverson (@Esity)
