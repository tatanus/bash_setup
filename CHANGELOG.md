# Changelog
All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `install.sh` flag `-n, --dry-run`. Previews install / update /
  uninstall actions (which dotfile arrays would be deployed, how many
  files / directories / recommended-tool checks would happen) and
  exits before any mutation. Brings bash_setup in line with
  `pentest_setup` and `scripts`, which already had `--dry-run`, and
  with `common_core` which gained it in the same review pass.
- Universal-flag block in `--help` updated to document the new flag.

### Changed

- `tools/check_bash_style.sh` synced from `scripts`' canonical version.
  Adds a filter that skips backslash-escaped backticks (`\\\``) when
  searching for command-substitution backticks, so heredocs that emit
  Markdown READMEs no longer false-positive. All four repos in the
  stack now share a byte-identical `tools/check_bash_style.sh`.
- `.github/CONTRIBUTING.md` replaced with the canonical version from
  `common_core/.github/CONTRIBUTING.md` (with `common_core` → `bash_setup`
  substitution). The previous file was the older template that still
  used the banned `-bn -kp` shfmt flags, recommended the banned
  `set -euo pipefail`, and left a `<your-username>/BASH` placeholder
  in the clone URL.
- `Makefile`'s `test` recipe now uses `find tests -name '*.bats'`
  instead of `ls tests/*.bats`. The old form silently missed tests
  under `tests/independent/` (and any other subdirectory) when no
  `.bats` files existed at the top level. Behavioral fix only; current
  tests pass in both forms because there were always top-level
  `.bats` files too.

### Removed

- `docs/ROADMAP.md`. It was a 3-line stub ("near-term goals may
  change based on feedback") with no content. The CHANGELOG is the
  canonical history for this repo.

## [2026.06.27.3] - 2026-06-27

### Removed

- `dotfiles/tgt.aliases.sh` and `dotfiles/capture_traffic.sh` were
  moved to `pentest_setup` ownership. Both are pure pen-test helpers
  (Kerberos TGT lifecycle and tshark-based traffic capture) that had
  ended up here for historical reasons. The placement caused a
  layering inversion CLAUDE.md flagged: `tgt.aliases.sh` referenced
  `ENGAGEMENT_DIR`, a variable that only `pentest_setup` defines, so
  `bash_setup` was depending on a downstream repo's exports. The
  previous workaround was an in-file `${HOME}/DATA` fallback default
  for `ENGAGEMENT_DIR`; that workaround is no longer needed because
  `pentest_setup`'s `pentest.path.sh` exports the variable
  unconditionally before either file is sourced.
- Both entries removed from `install.sh`'s `BASH_DOT_FILES` deploy
  array; both entries removed from `dotfiles/bashrc`'s
  `secondary_bash_files` source list. The `${BASH_DIR}/pentest.sh`
  hook (still optional, still deployed by `pentest_setup`) now sources
  these files in addition to the rest of the pentest dotfiles.
- README updated: file inventory, "What install.sh deploys" section,
  cross-repo contract section (the ENGAGEMENT_DIR safe-default note
  is gone), and the related troubleshooting entry all removed.

### Changed

- `tests/independent/85_bashrc_integration.bats`: dropped the
  `renewTGT (from tgt.aliases.sh) is defined` assertion -- the file
  is no longer here.
- `tests/independent/80_e2e_lifecycle.bats`: removed
  `tgt.aliases.sh` / `capture_traffic.sh` from the
  "install deploys the full BASH_DIR inventory" assertion list.
- `tests/independent/90_dotfile_syntax.bats`: dropped the
  source-guard carve-out for `capture_traffic.sh` (no longer here).
- Test suite is now 84 tests (was 85).

## [2026.06.27.2] - 2026-06-27

### Removed

- `.github/workflows/claude-gates.yml`. The workflow invoked
  `./.claude/tools/verify_bundle.sh` and `./.claude/tools/run_project_pipeline.sh`,
  but `.gitignore` excludes the entire `.claude/` directory from the
  repo. The toolchain has never been pushed, so GitHub's runner could
  not execute the steps and the workflow failed at the first script
  call (`No such file or directory`, exit 4).
- The "Claude Policy Gates" badge in `README.md`, which pointed at
  that now-removed workflow.

The standard CI gates (`make lint`, `make fmt-check`, `make test`)
continue to run on every push and PR via `.github/workflows/main.yml`,
which was added in `2026.06.27.0`. The `.claude/` toolchain is still
available locally for any contributor who has it deployed; it is
simply no longer wired to CI.

## [2026.06.27.1] - 2026-06-27

### Fixed

- `.github/workflows/claude-gates.yml`: rewrote with proper 2-space
  indentation. The whole file was using single-space indents which
  collapsed YAML's nesting: `branches: [main]` was a sibling of
  `push:` instead of nested inside it, so GitHub parsed `branches:`
  as an unknown top-level `on:` trigger and rejected the file with
  a YAML error pointing at `jobs:`. No change to the gate logic
  itself — same triggers, same 7 steps, same `.claude/tools/`
  invocations. One drive-by improvement: artifact upload step now
  has `if: always()` so failed runs still surface their diagnostic
  JSON.

## [2026.06.27.0] - 2026-06-27

### Added

- `tgt.aliases.sh` and `capture_traffic.sh` added to `install.sh`'s
  `BASH_DOT_FILES` array so they are now actually deployed to
  `${HOME}/.config/bash/`. Both also added to `dotfiles/bashrc`'s
  `secondary_bash_files` so they are sourced into the interactive shell.
  (This drift was previously documented as fixed but had regressed.)
- Safe-default fallback for `ENGAGEMENT_DIR` in `tgt.aliases.sh`
  (`: "${ENGAGEMENT_DIR:=${HOME}/DATA}"`) so the helper no longer crashes
  under `set -u` when sourced before `pentest_setup` defines the variable.
- `make fmt-check` (non-mutating shfmt diff), and `make ci` retargeted
  from `fmt + lint + test` (mutating) to `fmt-check + lint + test`
  (CI-safe).
- `make release V=...` and `make release-today` automated release-cut
  workflow: gated on `make ci`, stamps `## [Unreleased]` -> `## [V] -
  YYYY-MM-DD` in CHANGELOG, bumps VERSION, single commit + annotated
  tag, pushes with `--follow-tags`. Mirrors the workflow now in
  common_core.
- `.github/workflows/main.yml` standard CI workflow (shellcheck + pinned
  shfmt v3.8.0 + bats), running alongside the existing
  `claude-gates.yml` policy gates. README badges updated to reflect
  both.
- Explicit sourcing of `bash.funcs.sh`, `bash.prompt_funcs.sh`, and
  `bash-preexec.sh` from `dotfiles/bashrc`'s `secondary_bash_files`,
  before their consumers (`bash.aliases.sh`, `bash.prompt.sh`). Source
  guards keep the legacy implicit sourcing inside the consumers safe.
- `tests/independent/80_e2e_lifecycle.bats` (6 tests): end-to-end
  install → mutate → update → uninstall round-trip coverage.
- `tests/independent/85_bashrc_integration.bats` (5 tests): verifies the
  deployed bashrc actually loads what its `secondary_bash_files`
  declares, catching the same drift class Pass 1 fixed.
- `tests/independent/90_dotfile_syntax.bats` (5 tests): `bash -n` parse
  check on every shipped dotfile + source-guard presence check.
- Shared `create_mock_common_core` helper in
  `tests/independent/helpers/common.bash`, consolidating six divergent
  inline mock common_core copies that had drifted.

### Changed

- **README.md rewritten** to match the actual flat architecture
  (`install.sh` + `dotfiles/` + `tests/` + `tools/` + `Makefile`).
  Dropped references to a fictional `SetupBash.sh` entry point,
  `config/`, `menu/`, and a `lib/common_core` git submodule — none of
  which exist or ever existed in this repo. README now lists every
  file `install.sh` deploys and where it lands.
- `dotfiles/bash-preexec.sh` **rewritten in-tree** as a project-owned
  replacement for the vendored rcaloras/bash-preexec v0.5.0 (See
  Removed below). Same public API (`precmd_functions`,
  `preexec_functions`, `BP_PIPESTATUS`, `bash_preexec_imported`,
  `__bp_delay_install`, `__bp_enable_subshells`), same 11 internal
  function names, same observable behavior. Bash 4+ floor (dropped
  3.x compat shims). `function name() { ... }` form throughout with
  proc-doc blocks on every function.
- `tests/independent/helpers/common.bash`: replaced the divergent
  inline mock common_core heredocs across five test files with calls
  to the new shared helper. Test 69 in `70_validation_errors.bats`
  fixed: grep pattern was `^main()` against the project-mandated
  `function main() {` form, and the `-A 20` window did not reach
  `preflight_checks` ~40 lines into main()'s body.
- `Makefile`: `SEMVER_RE` extended to accept the project's 4-part
  date scheme (`YYYY.MM.DD.N`) in addition to classic 3-part semver.
  `tag` and `check-version` recipes collapsed to single chained
  recipe lines so the `v=$(cat VERSION); ...` shell variable persists
  into the next command (previously each recipe line ran in its own
  shell, producing an empty `v` tag).

### Fixed

- `tools/check_bash_style.sh` shfmt invocation: dropped `-bn -kp`,
  use mandated `-i 4 -ci -sr`. The wrong flags caused
  correctly-formatted files to be reported as malformed.
- `dotfiles/bash.env.sh`: replaced `eval "$(dircolors -b)"` (and the
  `gdircolors` variant) with `source <(dircolors -b)`. Same effect
  on LS_COLORS via process substitution; no eval keyword.
- `dotfiles/bash.visuals.sh` (`show_spinner`, `show_dots`,
  `show_timer`): eval calls now carry explicit
  `# shellcheck disable=SC2294` directives with rationale (caller
  passes an interactive shell command string; argv form would break
  the complex-command API contract). Vestigial SC2086 disable that
  did not match its target removed.
- 12 pre-existing BATS failures fixed in
  `tests/independent/60_files_differ_function.bats` (9 tests) and
  `tests/independent/70_validation_errors.bats` (3 tests). All twelve
  were test-side bugs (incomplete mock common_core missing
  `file::restore_old_backup`; wrong regex for `function main()`).

### Removed

- Vendored copy of rcaloras/bash-preexec v0.5.0 (replaced by the
  in-tree rewrite — see Changed). No upstream tracking burden going
  forward; project owns the file.

### Verification

- `make ci`: green.
- Test suite: 85 passing, 0 failing (was 69 passing / 12 failing
  before this release).
- `make lint`, `make fmt-check`, `make style`: all clean.

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
