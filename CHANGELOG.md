# Changelog
All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- Fixed incorrect path in `.github/workflows/main.yml` for style check script (was `./check_bash_style.sh`, now `./tools/check_bash_style.sh`)

### Changed
- Moved `dotfiles/COMBINED_HISTORY.md` to `docs/COMBINED_HISTORY.md`
- Removed `spec/` directory files (moved to `.claude/spec/` as internal pipeline infrastructure)

## [1.0.0] - 2025-01-11
### Added
- New unified `install.sh` script with install/update/uninstall commands
- Checksum-based update detection using SHA-256 (only copies changed files)
- `tools/` directory for CI/release scripts
- `tools/compile.sh` - CI/test/commit/release workflow orchestration
- `tools/check_bash_style.sh` - comprehensive Bash style checking
- `spec/tool-spec.json` - formal tool specification with 42 requirements
- `spec/architecture-plan.json` - locked architecture plan with dependency graph
- `spec/schemas/` - JSON schemas for spec validation
- `tests/independent/` - 58 independence tests for install/update/uninstall
- `.claude/` - pipeline infrastructure with audit logs and gate tracking
- Structured logging with FAIL/PASS/INFO/WARN/DEBUG levels
- Preflight checks for Bash 4+, HOME variable, and common_core availability
- Recommended tools check (eza, fzf, ncat, freeze, bat, duf, btop)

### Changed
- **BREAKING**: Requires system-installed `common_core` at `~/.config/bash/lib/common_core/`
- **BREAKING**: Removed git submodule dependency on common_core
- **BREAKING**: Removed interactive menu system - now CLI-only
- Consolidated `SetupBash.sh` and `menu/menu_tasks.sh` into single `install.sh`
- Updated Makefile with new targets (install, update, uninstall, style, ci)
- Restructured test suite with bats framework (69 total tests)
- Version now read from `VERSION` file at runtime
- Strict mode enforced: `set -uo pipefail`, `IFS=$'\n\t'`

### Removed
- `SetupBash.sh` - replaced by `install.sh`
- `menu/` directory - menu functionality removed
- `config/` directory - configuration now embedded in `install.sh`
- `update.sh` - no longer needed without submodules
- `.gitmodules` - submodule dependency removed
- `docs/CHANGELOG.md` - moved to root

### Security
- All scripts use strict mode (set -uo pipefail)
- IFS hardening to prevent word splitting issues
- Input validation on all CLI arguments
- Safe file operations with backup creation

### Migration Guide
1. Install `common_core` to `~/.config/bash/lib/common_core/`
2. Run `./install.sh install` instead of `./SetupBash.sh`
3. Use `./install.sh update` to update changed files only
4. Use `./install.sh uninstall` to restore original dotfiles

### Pipeline Certification
- Migration Pass 1: Certified (run_id: 7d2f0179)
- Migration Pass 2: Certified (run_id: f39e5a2d)
- All 16 gates passed with HARD_VETO enforcement
- Spec SHA256: c33e6d1448f61caaf47bbbd4857806bd421391701a0af5cc5e8282fc9c1c4813

## [0.9.4] - 2025-01-08
### Changed
- Pre-release version before major restructuring

## [0.9.0] - 2025-09-11
### Added
- Initial release with submodule-based common_core integration
