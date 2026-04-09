# Changelog

## [0.1.8] - 2026-04-09

### Changed
- `LEGION_PYTHON_VENV` constant reads `LEGION_PYTHON_VENV` env var first, falls back to `~/.legionio/python`

## [0.1.7] - 2026-04-09

### Added
- Python venv integration: route bare `python3`/`pip3` commands to Legion-managed venv (`~/.legionio/python`)
- `python3`, `python`, `pip3`, `pip` added to sandbox allowlist
- Runtime venv resolution via `Constants.venv_python`/`.venv_pip`/`.venv_exists?` (no longer frozen at load time)

## [0.1.6] - 2026-03-30

### Changed
- update to rubocop-legion 0.1.7, resolve all offenses

## [0.1.5] - 2026-03-29

### Changed
- All runner methods (`Bundler`, `Shell`, `Git`) accept `**` for task system payload compatibility

### Fixed
- Checkpoint spec: use `File::NULL` and `git add -f file.rb` to bypass global gitignore, fixing flaky restore spec on macOS

## [0.1.4] - 2026-03-22

### Changed
- Added runtime dependencies on legion-cache, legion-crypt, legion-data, legion-json, legion-logging, legion-settings, and legion-transport to gemspec
- Updated spec_helper to require real sub-gem helpers instead of inline stubs; added Helpers::Lex stub

## [0.1.3] - 2026-03-20

### Fixed
- Gemspec missing `spec.files` declaration — gem build previously produced an empty gem with no files
- Entry point missing `require_relative` for `Helpers::Checkpoint` and `Helpers::Worktree`

## [0.1.2] - 2026-03-20

### Added
- `Helpers::Worktree` for git worktree creation, removal, and listing
- `Helpers::Checkpoint` for hidden-ref-based state snapshots and restore

## [0.1.1] - 2026-03-18

### Fixed
- `Git.push` default branch changed from `'master'` to `'main'` to match GitHub's default since 2020

## [0.1.0] - 2026-03-13

### Added
- Initial release
