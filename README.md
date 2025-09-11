# bash_setup

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Build Status](https://github.com/tatanus/bash_setup/actions/workflows/main.yml/badge.svg)](https://github.com/tatanus/bash_setup/actions/workflows/main.yml)
[![Last Commit](https://img.shields.io/github/last-commit/tatanus/bash_setup)](https://github.com/tatanus/bash_setup/commits/main)

![Bash >=4.0](https://img.shields.io/badge/Bash-%3E%3D4.0-4EAA25?logo=gnu-bash&logoColor=white)

---

## Overview

`bash_setup` is a small framework for setting up a consistent Bash environment across Linux and macOS. It:

- Creates/validates a standard directory layout under `$HOME`
- Backs up and installs curated **dotfiles** (bashrc, inputrc, tmux.conf, etc.)
- Exposes menu-driven **tasks** to install/undo the dotfiles and perform setup
- Integrates **CI** (ShellCheck), **formatting** (shfmt), and basic **tests** (BATS)

## Submodules
## Submodules
## Submodules
<!-- SUBMODULES-LIST:START -->

* [lib/common_core](https://github.com/tatanus/common_core.git)

<!-- SUBMODULES-LIST:END -->



### Intended Execution Flow

1. **Entry point:** `./SetupBash.sh`
2. **Configuration:** sources `config/config.sh` (paths, dirs, logging) and `config/lists.sh` (dotfile lists & menu items)
3. **Core library:** sources `lib/common_core/lib/utils.sh` and `lib/common_core/lib/menu.sh` (logging, prompts, menu loop)
4. **Tasks:** sources `menu/menu_tasks.sh` (e.g., `Setup_Dot_Files`, `Undo_Setup_Dot_Files`, `Setup_Bash_Directories`)
5. **Dotfiles:** copies files from `./dotfiles/` into the right places, backing up any existing ones

> **Note:** This repo expects a `lib/common_core` **submodule** that provides shared functions such as logging, error handling, prompts, and menu helpers.

---

## Repository Layout

```
.
├── SetupBash.sh                # main entrypoint script
├── config/
│   ├── config.sh               # environment variables, dirs (DATA/, LOGS/, etc.)
│   └── lists.sh                # arrays of dotfiles and menu items
├── dotfiles/                   # bash/tmux/screen/vim/wget/curl configs & alias files
├── lib/
│   └── common_core/            # (git submodule) expected to contain lib/utils.sh, lib/menu.sh
├── menu/
│   └── menu_tasks.sh           # functions: Setup_Dot_Files, Undo_Setup_Dot_Files, Setup_Bash_Directories
├── tests/
│   └── ...                     # BATS sanity tests
├── Makefile                    # helper targets (lint/format/test/install/run/etc.)
└── README.md
```

---

## Requirements

- **Bash** ≥ 4.0 (Linux default; on macOS you may need to install via Homebrew)
- **git** (for submodules)
- Recommended for development:
  - **ShellCheck** (lint)
  - **shfmt** (format)
  - **BATS** (tests)

macOS users can install these via Homebrew; Linux users via apt/yum/pacman as appropriate.

---

## Quick Start

```bash
# 1) Clone the repo
git clone https://github.com/tatanus/bash_setup.git
cd bash_setup

# 2) Fetch the core submodule(s)
git submodule update --init --recursive

# 3) (Dev) Install tools (examples)
#   macOS: brew install shellcheck shfmt bats-core
#   Ubuntu: sudo apt-get update && sudo apt-get install -y shellcheck shfmt bats

# 4) Run lint/format/tests (optional, recommended)
make lint
make fmt
make test

# 5) Run the setup
./SetupBash.sh
```

---

## What gets installed?

From `config/lists.sh`, the default dotfiles include (not exhaustive):

- `dotfiles/bashrc`, `dotfiles/bash_profile`, `dotfiles/profile`
- `dotfiles/inputrc`
- `dotfiles/tmux.conf` and `tmux.aliases.sh`
- `dotfiles/screenrc_v4`, `screenrc_v5`, `screen.aliases.sh`
- `dotfiles/vimrc`
- `dotfiles/curlrc`, `dotfiles/wgetrc`
- Various `*.aliases.sh`, `bash.*.sh` helpers (env, funcs, path, prompt, visuals, ssh, tgt, etc.)

You can tailor the installation list by editing **`config/lists.sh`** arrays.

---

## Tasks / Menu

From `menu/menu_tasks.sh`:

- `Setup_Dot_Files` — Back up existing user dotfiles and replace with repo versions
- `Undo_Setup_Dot_Files` — Restore backups and remove installed dotfiles
- `Setup_Bash_Directories` — Create expected directories (e.g., `${HOME}/DATA`, `${HOME}/DATA/LOGS`)

These are typically surfaced through a menu (provided by `lib/common_core/lib/menu.sh`) that the entrypoint script calls.

---

## Configuration

`config/config.sh`:

- Establishes `${HOME}` assumptions & derived dirs:
  - `${DATA_DIR}="${HOME}/DATA"`
  - `${LOGS_DIR}="${DATA_DIR}/LOGS"`
  - `${BASH_DIR}` / `${BASH_LOG_FILE}` and other script-internal paths
- Central place to enable/disable logging to file, tweak defaults, etc.

`config/lists.sh`:

- The lists of **dotfiles** to install
- The list of **menu items** to expose

---

## Development

Common commands:

```bash
# lint bash files with ShellCheck
make lint

# format with shfmt
make fmt

# run tests (BATS)
make test
```

---

## Troubleshooting

- **Missing functions like `info/pass/warn/fail`**  
  → These come from `lib/common_core/lib/utils.sh`. Confirm the submodule is present and sourced.

- **macOS `getent` not found**  
  → The entrypoint has a fallback for resolving `$HOME`, but prefer cross-platform checks. Verify `whoami`, `$HOME`, and `dscl`/`id` as needed.

- **Dotfiles not installed**  
  → Check `config/lists.sh` is sourced and arrays are populated; run `Setup_Bash_Directories` first; verify write permissions in `$HOME`.

---

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork this repository.
2. Create a branch for your feature or fix.
3. Commit your changes and push to your fork.
4. Submit a pull request.

---

## License

This project is licensed under the [MIT License](LICENSE).

---

## Notes

For any questions, feature requests, or bug reports, feel free to open an issue or contact the repository owner.
