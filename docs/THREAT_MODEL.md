# Threat Model — bash_setup

**Scope**: Bash scripts that configure shell environments, dotfiles, and tooling.
This includes installation, updates, and undo/cleanup functions, plus CI and release artifacts.

## Assets
- User shell configuration (`~/.bashrc`, `~/.bash_profile`, custom dirs/files)
- Installer scripts and helper utilities
- Release archives and checksums
- Logs containing environment details

## Actors
- Legitimate users running local setup
- Malicious local users with access to the same host
- Network attackers influencing downloads or package registries
- Supply-chain attackers modifying dependencies or release artifacts

## Trust boundaries
- Local user ↔ system configuration (privilege boundaries with `sudo`)
- Local host ↔ external networks (package mirrors, GitHub)
- Source repo ↔ CI runners ↔ release storage

## Risks (STRIDE summary)
| Threat            | Example                                              | Risk | Mitigations                                                |
|-------------------|------------------------------------------------------|------|------------------------------------------------------------|
| Spoofing          | MITM of script/dependency download                   | H    | HTTPS only; pin sources; verify checksums/signatures       |
| Tampering         | PATH hijack / alias shadowing                        | H    | Use absolute paths; quote variables; avoid `eval`; `set -Euo pipefail` |
| Repudiation       | Lack of audit trail for destructive actions          | M    | Structured logging; timestamps; `dry-run` modes            |
| Information Disc. | Secrets printed in logs                              | M    | Redaction; avoid echoing sensitive env; minimal verbosity  |
| DoS               | Partial installs leave system unusable               | M    | Idempotent steps; `trap` cleanup; rollback/undo functions  |
| Elevation         | Insecure `sudo` usage or unsafe file perms           | H    | Minimize `sudo`; check file modes; use `umask 022`; validate inputs |

## Security requirements
- Defensive shell style: `set -Euo pipefail`, safe IFS, strict quoting, `mktemp` for temp files, `trap` for cleanup
- Avoid `eval`; never execute untrusted input
- Verify remote downloads (checksums/signatures); pin git refs
- Use absolute paths and explicit interpreters (e.g., `/usr/bin/env bash`)
- Limit and audit `sudo` operations; fail closed on errors
- Secret scanning in CI (`gitleaks.toml`)
- Reproducible release archives with checksums and release notes

## Residual risks
- Third-party mirrors or dependencies may change unexpectedly
- User local customization can conflict with managed files

## References
- `SECURITY.md`, `RELEASING.md`
