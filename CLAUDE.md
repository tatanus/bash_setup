# CLAUDE.md - Project Context for Claude

## Project Overview

**bash_setup** is a Bash dotfiles installer and manager that provides install, update, and uninstall commands for shell configuration files. It uses checksum-based change detection and automatic backup management.

## Architecture

- **Language Mode**: Pure Bash (`language_mode: bash`)
- **Design**: Monolithic single-file architecture
- **Entrypoint**: `install.sh` (all logic in one file, ~520 lines)
- **External Dependency**: Requires `common_core` library at `~/.config/bash/lib/common_core/`

## Key Files

| File | Purpose |
|------|---------|
| `install.sh` | Main CLI entrypoint with install/update/uninstall commands |
| `dotfiles/` | Source configuration files to be installed |
| `tools/check_bash_style.sh` | Bash style enforcement (ShellCheck + custom rules) |
| `tools/compile.sh` | CI/test/commit/release workflow orchestration |
| `spec/tool-spec.json` | Formal tool specification (42 requirements) |
| `spec/architecture-plan.json` | Locked architecture plan with dependency graph |
| `tests/` | bats test suites (69 total tests) |
| `tests/independent/` | Independence tests (58 tests, immutable during repair) |

## Commands

```bash
./install.sh install      # Install dotfiles with backups
./install.sh update       # Update only changed files (SHA-256 comparison)
./install.sh uninstall    # Restore original files from backups
./install.sh --help       # Show usage
./install.sh --version    # Show version
```

## Development Workflow

```bash
make fmt      # Format with shfmt
make lint     # Run ShellCheck
make test     # Run bats tests
make style    # Comprehensive style check
make ci       # fmt + lint + test
```

## Critical Constraints

### Bash Requirements
- **Version**: Bash 4.0+ required
- **Strict Mode**: All scripts must use `set -uo pipefail` and `IFS=$'\n\t'`
- **Banned Patterns**: `set -e`, backticks, `echo -e`, `for f in $(ls)`

### External Dependency
The tool requires `common_core` library pre-installed:
```
~/.config/bash/lib/common_core/
└── util.sh  # Provides file::copy, file::restore_old_backup, logging functions
```

### File Patterns
- **Allowed**: `*.sh` scripts with proper shebang and strict mode
- **Forbidden**: Python files in implementation, `lib/*.sh` modules (monolithic design)

## Testing

- **Framework**: bats (Bash Automated Testing System)
- **Test Files**:
  - `tests/00_bootstrap.bats` - Repository structure validation
  - `tests/10_install_help.bats` - CLI interface tests
  - `tests/20_preflight.bats` - Preflight checks validation
  - `tests/independent/*.bats` - Independence tests (DO NOT MODIFY during repair loops)

## Pipeline Infrastructure

The `.claude/` directory contains pipeline infrastructure (gitignored):
- `agents/` - Gate definitions for automated validation
- `audit-logs/` - Audit trail for pipeline runs
- `internal/` - Runtime state (run.json, feedback-loop.json)
- `schemas/` - JSON schemas for validation

### Pipeline Gates
The project uses a multi-gate pipeline with HARD_VETO enforcement:
- spec-validator, plan-validator, traceability-gate
- language-mode-validator, bash-style-enforcer, shellcheck-gate
- test-author, artifact-policy-gate, release-manager

## Version Information

- **Current Version**: 1.0.0
- **Spec SHA256**: `c33e6d1448f61caaf47bbbd4857806bd421391701a0af5cc5e8282fc9c1c4813`
- **Pipeline Status**: Certified (Pass 1 + Pass 2)

## Important Notes for Claude

1. **Do not create Python files** - This is a bash-only project
2. **Do not create `lib/*.sh` modules** - Monolithic architecture by design
3. **Do not modify `tests/independent/`** - These are immutable during repair loops
4. **Always use strict mode** in new scripts: `set -uo pipefail`, `IFS=$'\n\t'`
5. **Third-party code** (`dotfiles/bash-preexec.sh`) has `shellcheck disable=all` - don't enforce style on it
6. **Common patterns**: Use `file::copy`, `file::restore_old_backup` from common_core for file operations

## Quick Reference

```bash
# Run all checks before committing
make ci

# Check style compliance
make style

# Run specific test file
bats tests/10_install_help.bats

# Format all scripts
make fmt
```
