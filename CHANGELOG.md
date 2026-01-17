# Changelog
All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2026.01.16.0] - 2026-01-16

### Added
- Proc-doc blocks for ~30 functions across dotfiles and tools
- CI workflow `claude-gates.yml` for automated gate validation
- `.markdownlintignore` for markdown linting exclusions

### Changed
- Updated `.editorconfig` with standardized formatting rules
- Updated `.gitattributes` with language detection hints
- Updated `.gitignore` for `.claude/` infrastructure patterns
- Updated `.shellcheckrc` configuration
- Updated `.markdownlint.yaml` with relaxed linting rules
- Improved `tools/compile.sh` with full proc-doc coverage
- Improved `tools/check_bash_style.sh` style checks
- Updated test helpers in `tests/helpers/common.bash`

### Removed
- Deprecated `codacy.yml` workflow
- Deprecated `main.yml` workflow

### Fixed
- ShellCheck suppressions for external variables in dotfiles
- SC2034 suppression for unimplemented quiet mode in install.sh
- IFS assignments added where missing

## [1.0.0] - 2024-12-08

### Added
- Initial release of bash_setup dotfiles installer
- Install, update, and uninstall commands
- Checksum-based change detection
- Automatic backup management
