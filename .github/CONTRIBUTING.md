# Contributing

Welcome to the project! We're excited to have you contribute. Whether you're
fixing a bug, improving documentation, or proposing a new feature, your
contributions are greatly appreciated. Follow the guidelines below to ensure
a smooth and productive collaboration.

---

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [How to Contribute](#how-to-contribute)
   - [Reporting Issues](#reporting-issues)
   - [Submitting Code Changes](#submitting-code-changes)
   - [Improving Documentation](#improving-documentation)
4. [Style Guide](#style-guide)
5. [Quality Gates](#quality-gates)
6. [Pull Request Process](#pull-request-process)
7. [Contact](#contact)

---

## Code of Conduct

This project adheres to the
[Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/version/2/0/code_of_conduct/).
By participating, you are expected to uphold this code. Please report
unacceptable behavior to the project maintainer.

---

## Getting Started

1. **Fork the repository** to your own GitHub account.
2. **Clone your fork**:
   ```bash
   git clone https://github.com/tatanus/bash_setup.git
   cd bash_setup
   ```
3. **Install dependencies**:
   - Bash 4+ (macOS users: `brew install bash`).
   - `shellcheck` and `shfmt` for style enforcement.
   - `bats` (bats-core) for running the test suite.
   ```bash
   # Ubuntu/Debian
   sudo apt install shellcheck bats
   # shfmt: install via go or download from https://github.com/mvdan/sh/releases

   # macOS
   brew install shellcheck shfmt bats-core
   ```
4. **Verify your environment**:
   ```bash
   make ci    # runs fmt-check + lint + tests
   ```

---

## How to Contribute

### Reporting Issues

If you've found a bug or have a feature request, please open an issue on
GitHub:

1. Click on **Issues**.
2. Select **New Issue**.
3. Provide a clear and concise description of the problem or feature,
   including:
   - Steps to reproduce (if it's a bug).
   - Expected behavior versus actual behavior.
   - Any error messages or logs.

### Submitting Code Changes

1. **Create a new branch** from `master`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. **Make your changes**. Follow the [Style Guide](#style-guide).
3. **Run the local quality gate**:
   ```bash
   make ci    # fmt-check + lint + bats tests, non-mutating
   ```
   If `make fmt-check` reports drift, run `make fmt` to auto-format.
4. **Add or update tests**. Unit tests live in `tests/unit/*.bats`;
   integration tests in `tests/integration/`. New `util_X.sh` helpers
   should ship with `test_util_X.bats` coverage.
5. **Update documentation**:
   - If you add or rename a public function, update the matching
     `docs/util_X.md`. Run `make check-docs` to catch drift.
   - If your change is user-visible, add a line under `## [Unreleased]`
     in `CHANGELOG.md` (Added / Changed / Fixed / Removed / Security).
6. **Commit your changes** with a descriptive message:
   ```bash
   git commit -m "fix(util_file): handle symlink targets in file::backup"
   ```
7. **Push the branch**:
   ```bash
   git push origin feature/your-feature-name
   ```
8. Open a **Pull Request (PR)** against `master`.

### Improving Documentation

Documentation improvements are highly valued. The canonical sources are:

- `README.md` — project overview and quick start.
- `CHANGELOG.md` — Keep-a-Changelog format; add notable changes to
  `## [Unreleased]`.
- `docs/util_*.md` — one per `lib/utils/util_*.sh` module. Function
  signatures here must match the source; `make check-docs` enforces this.
- `docs/ROADMAP.md` — near-term goals.

To propose doc-only changes, follow the same branch / PR flow as code.

---

## Style Guide

The mandatory bash conventions (enforced by `.shellcheckrc` and the
`tools/*.sh` gates):

- **Bash 4+**, `set -uo pipefail`, `IFS=$'\n\t'`.
- **No `set -e`** — handle errors explicitly via `||` / `return`.
- **No `eval`** outside of heavily-audited metaprogramming (with a
  rationale comment).
- **`function name() { ... }`** form for every function — never bare
  `name() { ... }`.
- **Quote all expansions**: `"${var}"`, `"$@"`. ShellCheck enforces
  `require-variable-braces` (SC2250) — even safe references take braces.
- **`[[ ... ]]`** instead of `[ ... ]` (enforced via
  `require-double-brackets`).
- **`command -v`** instead of `which`.
- **`$(...)`** instead of backticks.
- **Source-guard idiom** to prevent double-loading:
  ```bash
  if [[ -n "${X_LOADED:-}" ]]; then
      if (return 0 2> /dev/null); then return 0; fi
  else
      X_LOADED=1
  fi
  ```

### Function header template

Every public function should carry a proc-doc block in this form:

```bash
###############################################################################
# module::function_name
#------------------------------------------------------------------------------
# Purpose  : One-line description of what the function does.
# Usage    : module::function_name "arg1" "arg2"
# Arguments:
#   $1 : Description of first argument
#   $2 : Description of second argument
# Returns  : PASS (0) on success, FAIL (1) on error
# Outputs  : What is written to stdout (if anything)
# Globals  : Any global variables read or set
# Requires :
#   Functions: list of helper functions called
#   Commands : list of external binaries called
###############################################################################
function module::function_name() {
    local arg1="${1:-}"
    ...
}
```

---

## Quality Gates

All quality targets live in the `Makefile` and delegate to the scripts in
`tools/`. Run them locally before opening a PR; CI
(`.github/workflows/main.yml`) runs the same gates on every push and PR.

| Target              | What it does                                                     |
|---------------------|------------------------------------------------------------------|
| `make ci`           | Format check + lint + tests. Non-mutating. **Run before PR.**    |
| `make fmt`          | Auto-format with `shfmt -i 4 -ci -sr` (writes in place).         |
| `make fmt-check`    | Verify formatting without writing; same flags as `make fmt`.     |
| `make lint`         | `shellcheck -x` across tracked `*.sh`.                           |
| `make test`         | `bats -r tests` (unit + integration).                            |
| `make style`        | Comprehensive style scan (banned patterns: `set -e`, backticks). |
| `make check-docs`   | Detect drift between `docs/util_*.md` and `lib/utils/util_*.sh`. |

The mandated `shfmt` flags are **`-i 4 -ci -sr`**. Do not add `-bn` or
`-kp` — they conflict with the project formatting. The mandated
`shellcheck` invocation is **`shellcheck -x`** (with the repo's
`.shellcheckrc` picked up automatically).

---

## Pull Request Process

1. Ensure your branch is up-to-date with `master`:
   ```bash
   git fetch origin
   git rebase origin/master
   ```
2. Confirm `make ci` is green locally.
3. Include a detailed PR description outlining:
   - What changes were made.
   - Why the changes were made.
   - Any impact on existing functionality (including downstream repos:
     `bash_setup`, `scripts`, `pentest_setup`, `pentest_menu`).
4. Address PR comments promptly to keep the review process efficient.

---

## Contact

If you have any questions, feel free to reach out via:

- **Issues**: Use the
  [Issues](https://github.com/tatanus/bash_setup/issues) tab.

Thank you for contributing and helping make **bash_setup** better!
