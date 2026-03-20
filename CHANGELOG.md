# Changelog

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
