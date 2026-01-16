# CLAUDE.md

This file is **auto-generated** by `.claude/tools/generate_claude_md.sh`.
Do not edit by hand. Regenerate via `@generate_claude_md`.

## Authority & Hashes
- Bash Style Guide: `.claude/style/bash-style-guide.md` (sha256: b3461a002202d80eaca082e673fda0fa645e2da1b5ff008fd121b35476cb9fc6)
- ShellCheck Policy: `.claude/policy/shellcheck-policy.yaml` (sha256: 5f340fc9f1e05f8234809e29b23a13f28ad7b7ddf2d757e4a3f84c3696b01e15)
- Orchestration Pipeline: `.claude/orchestrator/pipeline.yaml` (sha256: f69e7374a25d6a79b272df2ab50c248f099ad0997897019f86c233a1667b44ef)

## Platform Targets
- Bash: 4+ (minimum), 5+ supported
- zsh: 5.9+ best-effort (via `emulate -L sh` prologue)
- OS: macOS, Linux, WSL2

## Non-Negotiable Rules
- Use `set -uo pipefail`; **ban** `set -e`.
- Enforce `function name() { ... }` for new/refactored functions.
- Proc-doc blocks required for all non-trivial functions.
- Data-producing functions: stdout-only; logging to stderr only.
- Prefer common_core utilities under ${HOME}/.config/bash/lib/common_core when available.
  Use `.claude/tools/common_core_lookup.sh` first to avoid reinventing functions.

## Canonical Prologue (Strict Mode)
```bash
#===============================================================================
# Strict Mode (Bash-first, zsh best-effort)
#===============================================================================
if [[ -n "${ZSH_VERSION:-}" ]]; then
    emulate -L sh
    setopt NO_UNSET
    setopt PIPE_FAIL
    setopt NO_BEEP
fi

set -uo pipefail
IFS=$'\n\t'
```

## Trap Policy (When Needed)
```bash
#===============================================================================
# Trap Policy (use when cleanup is required)
#===============================================================================
# trap exit_on_signal_sigint SIGINT
# trap exit_on_signal_sigterm SIGTERM
#
# exit_on_signal_sigint(){ warn "Interrupted (SIGINT)"; exit 130; }
# exit_on_signal_sigterm(){ warn "Terminated (SIGTERM)"; exit 143; }
```

## Function + Proc-Doc + Logging Policies (Critical Excerpts)
```text
#===============================================================================
# Function Declaration Policy
#===============================================================================
# Required for all new/refactored code:
#   function name() {
#
# Forbidden:
#   name() {
#
# Note: The pipeline includes an automatic legacy rewrite gate for name() declarations.

#===============================================================================
# Proc-Doc Policy
#===============================================================================
# All non-trivial functions MUST have a proc-doc block using the project template.
# Canonical checker:
#   .claude/tools/validate_proc_docs.sh

#===============================================================================
# Logging & Stdout/Stderr Policy
#===============================================================================
# - Functions that produce data MUST write data to stdout only.
# - Logging MUST go to stderr via logger functions (info/warn/error/debug/pass/fail).
# - Never mix data output with logging.
```

## Gates (CI / Local Parity)
CI blocks merges when any gate fails. Soft fails are advisory only.
Use the deterministic runners:
- Project: `.claude/tools/run_project_pipeline.sh`
- Workspace: `.claude/tools/run_workspace_pipeline.sh`

## Tests Policy (A)
- If tests are detected: they MUST pass.
- If no tests are detected: tests gate PASS.

## Regeneration
- Update style/policy/pipeline -> run `@generate_claude_md` and commit updated outputs.
