# bash_setup

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/tatanus/bash_setup/actions/workflows/main.yml/badge.svg)](https://github.com/tatanus/bash_setup/actions/workflows/main.yml)
[![Last Commit](https://img.shields.io/github/last-commit/tatanus/bash_setup)](https://github.com/tatanus/bash_setup/commits/main)

![Bash >=4.0](https://img.shields.io/badge/Bash-%3E%3D4.0-4EAA25?logo=gnu-bash&logoColor=white)

---

## Overview

`bash_setup` ships a curated set of Bash dotfiles (bashrc, prompt, aliases,
history, screen/tmux configs, helpers) along with an installer that deploys
them to `${HOME}/.config/bash/` and wires them into the user's shell.

It is the second repo in a five-repo stack:

```
common_core  →  bash_setup  →  scripts  →  pentest_setup  →  pentest_menu
```

`bash_setup` depends on **common_core** being installed first at
`${HOME}/.config/bash/lib/common_core/util.sh`. The installer's preflight
will refuse to run otherwise.

---

## Requirements

- **Bash 4+** (Linux ships with this by default; on macOS install via
  `brew install bash`)
- **common_core** installed at `${HOME}/.config/bash/lib/common_core/`
  (see [common_core](https://github.com/tatanus/common_core))
- Recommended for development:
  - `shellcheck` (lint)
  - `shfmt` (format) — must support `-i 4 -ci -sr`
  - `bats` (test)

macOS: `brew install shellcheck shfmt bats-core`
Ubuntu/Debian: `sudo apt-get install shellcheck bats` (shfmt: install via
`go install mvdan.cc/sh/v3/cmd/shfmt@latest` or the GitHub releases page).

---

## Quick Start

```bash
# 1. Install common_core first
git clone https://github.com/tatanus/common_core.git
cd common_core
make install   # deploys to ${HOME}/.config/bash/lib/common_core/
cd ..

# 2. Clone and install bash_setup
git clone https://github.com/tatanus/bash_setup.git
cd bash_setup
make install   # equivalent to: bash install.sh install

# 3. Start a new shell or source the deployed bashrc
exec bash -l
```

---

## Repository Layout

```
.
├── install.sh                  # install / update / uninstall flow
├── Makefile                    # quality gates + release automation
├── VERSION                     # date-based version: YYYY.MM.DD.N
├── CHANGELOG.md                # Keep a Changelog (see Releases below)
├── dotfiles/                   # files deployed to ${HOME}/.config/bash/
│   ├── bashrc, profile, bash_profile
│   ├── bash.path.sh            # PATH, GOPATH, macOS Homebrew adjustments
│   ├── bash.env.sh             # locale, editor, history, dircolors
│   ├── path.env.sh             # BASH_DIR, BASH_LOG_DIR
│   ├── bash.funcs.sh           # check_command, _get_os, history_search
│   ├── bash.aliases.sh         # ls / ll / grep / etc. wrappers
│   ├── bash.prompt.sh          # PS1 builder
│   ├── bash.prompt_funcs.sh    # prompt helper functions
│   ├── bash.visuals.sh         # colored helpers, spinners
│   ├── bash-preexec.sh         # preexec / precmd hooks
│   ├── combined.history.sh     # cross-shell history merge
│   ├── screen.aliases.sh       # screen wrappers
│   ├── tmux.aliases.sh         # tmux wrappers
│   ├── ssh.aliases.sh          # ssh wrappers
│   ├── tmux.conf, screenrc_v4, screenrc_v5
│   ├── inputrc, vimrc, curlrc, wgetrc
├── tests/                      # BATS coverage
│   ├── 00_bootstrap.bats
│   ├── 10_install_help.bats
│   ├── 20_preflight.bats
│   ├── independent/            # update-mode + validation tests
│   └── helpers/
├── tools/
│   └── check_bash_style.sh     # comprehensive style scan
└── docs/                       # CHANGELOG, ROADMAP, design notes
```

### What `install.sh` deploys

`install.sh` copies two groups of files from `dotfiles/`:

- **COMMON_DOT_FILES** → `${HOME}/` directly: `bashrc`, `profile`,
  `bash_profile`, `tmux.conf`, `screenrc_v4`, `screenrc_v5`, `inputrc`,
  `vimrc`, `wgetrc`, `curlrc`.
- **BASH_DOT_FILES** → `${HOME}/.config/bash/`: the `bash.*.sh` helpers,
  `*.aliases.sh`, `combined.history.sh`, `bash-preexec.sh`.

The deployed `bashrc` sources `bash.path.sh`, `bash.env.sh`, and
`path.env.sh` first (they set `BASH_DIR` and `PATH`), then walks
`secondary_bash_files=(…)` to source the rest, with a final optional
`${BASH_DIR}/pentest.sh` hook for the downstream `pentest_setup` repo.
Pentest-specific helpers — Kerberos TGT helpers (`tgt.aliases.sh`),
the traffic-capture wrapper (`capture_traffic.sh`), and the screenshot
helper (`screenshot.sh`) — are deployed by `pentest_setup` and reach
the shell through that hook.

---

## Make targets

| Target              | What it does                                                        |
|---------------------|---------------------------------------------------------------------|
| `make help`         | Show all targets.                                                   |
| `make ci`           | Format check + lint + tests. **Non-mutating. Run before PRs.**      |
| `make fmt`          | Auto-format with `shfmt -i 4 -ci -sr` (writes in place).            |
| `make fmt-check`    | Verify formatting without writing; same flags as `make fmt`.        |
| `make lint`         | `shellcheck -x` across `git ls-files '*.sh'`.                       |
| `make test`         | `bats -r tests`.                                                    |
| `make style`        | Comprehensive style scan via `tools/check_bash_style.sh`.           |
| `make install`      | `bash install.sh install` — deploy dotfiles.                        |
| `make update`       | `bash install.sh update` — refresh only changed dotfiles.           |
| `make uninstall`    | `bash install.sh uninstall` — restore backups.                      |
| `make show-version` | Print current `VERSION`.                                            |
| `make release V=…`  | Cut a release (see [Releases](#releases)).                          |
| `make release-today`| Cut a release using today's UTC date (`YYYY.MM.DD.0`).              |

The mandated formatter flags are **`-i 4 -ci -sr`**. Do not add `-bn` or
`-kp` anywhere — they conflict with the project formatting.

---

## Style conventions

Enforced by `.shellcheckrc` and `tools/check_bash_style.sh`:

- Bash 4+, `set -uo pipefail`, `IFS=$'\n\t'`.
- **No `set -e`** — handle errors explicitly.
- **No `eval`** outside heavily-audited metaprogramming.
- `function name() { … }` form; never bare `name() { … }`.
- All expansions quoted and braced (`"${var}"`, `"$@"`).
- `[[ … ]]` not `[ … ]`; `command -v` not `which`; `$(…)` not backticks.
- Source-guard idiom on every helper:
  ```bash
  if [[ -z "${X_LOADED:-}" ]]; then
      declare -g X_LOADED=true
      # …
  fi
  ```

See `CLAUDE.md` (auto-generated) for the canonical policy hash chain.

---

## Cross-repo contract

bash_setup ships a `bashrc` that *optionally* sources
`${BASH_DIR}/pentest.sh` if present. That file is **not** deployed by
bash_setup; it is deployed by the downstream `pentest_setup` repo as its
hook into the user shell. The guard (`[[ -f "${file}" ]]`) keeps the load
silent when pentest_setup is not installed.

There used to be a special note here about bash_setup's `tgt.aliases.sh`
needing to fall back to a `${HOME}/DATA` default when sourced before
`pentest_setup` exported `ENGAGEMENT_DIR`. That layering inversion is
now gone: `tgt.aliases.sh` (and the matching `capture_traffic.sh`)
have moved to `pentest_setup` ownership, where `ENGAGEMENT_DIR` is set
unconditionally by `pentest.path.sh` before either file is sourced.

---

## Releases

The repo uses date-based four-part versioning (`YYYY.MM.DD.N`), tracked in
`VERSION` and `CHANGELOG.md`. To cut a release:

```bash
# 1. Land your changes as normal commits with `## [Unreleased]` notes.
git add …; git commit -m "feat(…): …"; git push

# 2. Cut the release. `make release` will:
#    - run `make ci` (refuse if anything fails)
#    - refuse on a dirty working tree
#    - stamp `## [Unreleased]` -> `## [Vx] - YYYY-MM-DD` (UTC) in CHANGELOG
#    - write VERSION
#    - single commit `chore(release): cut Vx`
#    - annotated tag `vVx`
#    - `git push --follow-tags`
make release-today          # uses today's UTC date.0
make release-today N=1      # second cut of the same UTC day -> .1
make release V=2026.06.25.0 # explicit version
```

---

## Troubleshooting

**`install.sh` aborts with "common_core library not found"**
→ Install [common_core](https://github.com/tatanus/common_core) first.
   The installer expects `${HOME}/.config/bash/lib/common_core/util.sh`.

**`bash.aliases.sh` complains about missing `check_command`**
→ `bash.aliases.sh` sources `bash.funcs.sh` on load. If `bash.funcs.sh`
   was not deployed, re-run `make install` and verify it landed in
   `${HOME}/.config/bash/`.

**`make style` reports drift on files that look correct**
→ Check `tools/check_bash_style.sh` is invoking `shfmt -i 4 -ci -sr`
   (not `-bn -kp`). The wrong flags produce false positives.

---

## Contributing

See [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md) if present;
otherwise, the contract is:

1. Branch from `main`.
2. Run `make ci` locally — it must be green before opening a PR.
3. If your change is user-visible, add a bullet under `## [Unreleased]`
   in `CHANGELOG.md`.
4. Open a PR against `main`.

---

## License

This project is licensed under the [MIT License](LICENSE).
