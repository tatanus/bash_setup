# CLAUDE_HUMAN.md

This file is **auto-generated** by `.claude/tools/generate_claude_md.sh`.
It explains the LLM contract and how it maps to CI gates.

## What this system enforces
- Consistent Bash style and security posture across macOS/Linux/WSL2
- Deterministic gate execution locally and in CI
- A strict, auditable loop: propose -> apply -> gate -> repair brief -> fix loop (optional)

## Key constraints (why they exist)
- `set -uo pipefail` without `set -e`: predictable failure handling and debuggability.
- `function name()` only: consistent parsing and easier proc-doc enforcement.
- Proc-doc blocks: maintainability and consistent usage/contracts.
- Stdout vs stderr separation: enables functions to be safely composed and parsed.

## How CI decides PASS/FAIL
CI runs `.claude/tools/run_project_pipeline.sh` and fails the build if `gates.json:any_fail == true`.
ShellCheck uses a policy engine:
- Hard-fail codes: CI failure
- Soft-fail codes: advisory (still surfaced in CI comments)

## When to regenerate
Regenerate and commit `CLAUDE.md` and `CLAUDE_HUMAN.md` whenever you change:
- `.claude/style/bash-style-guide.md`
- `.claude/policy/shellcheck-policy.yaml`
- `.claude/orchestrator/pipeline.yaml`

## References
- Full Style Guide: `.claude/style/bash-style-guide.md` (sha256: b3461a002202d80eaca082e673fda0fa645e2da1b5ff008fd121b35476cb9fc6)
- ShellCheck Policy: `.claude/policy/shellcheck-policy.yaml` (sha256: 5f340fc9f1e05f8234809e29b23a13f28ad7b7ddf2d757e4a3f84c3696b01e15)
- Pipeline: `.claude/orchestrator/pipeline.yaml` (sha256: f69e7374a25d6a79b272df2ab50c248f099ad0997897019f86c233a1667b44ef)
