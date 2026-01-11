# Changelog
All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2025-01-09
### Added
- New unified `install.sh` script with install/update/uninstall commands
- Checksum-based update detection (only copies changed files)
- `tools/` directory for CI/release scripts
- `tools/compile.sh` - CI/test/commit/release workflow
- `tools/check_bash_style.sh` - comprehensive style checking

### Changed
- **BREAKING**: Requires system-installed `common_core` at `~/.config/bash/lib/common_core/`
- **BREAKING**: Removed git submodule dependency on common_core
- Consolidated `SetupBash.sh` and `menu/menu_tasks.sh` into single `install.sh`
- Updated Makefile with new targets (install, update, uninstall, style)
- Simplified test suite for new structure
- Version now read from `VERSION` file at runtime

### Removed
- `SetupBash.sh` - replaced by `install.sh`
- `menu/` directory - menu functionality removed (CLI-only)
- `config/` directory - configuration now embedded in `install.sh`
- `update.sh` - no longer needed without submodules
- `.gitmodules` - submodule dependency removed
- Interactive menu system - now uses CLI flags only
- `menu_timestamps` file - no longer needed

### Migration Guide
1. Install `common_core` to `~/.config/bash/lib/common_core/`
2. Run `./install.sh` instead of `./SetupBash.sh`
3. Use `./install.sh update` to update changed files only
4. Use `./install.sh uninstall` to restore original dotfiles

## [0.9.4] - 2025-01-08
### Changed
- Pre-release version before major restructuring

## [0.9.0] - 2025-09-11
### Added
- Initial release with submodule-based common_core integration
