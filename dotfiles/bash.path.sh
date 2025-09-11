#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# NAME        : bash.path.sh
# DESCRIPTION : Sets the PATH variable for different environments.
# AUTHOR      : Adam Compton
# DATE CREATED: 2024-12-08 19:57:22
# =============================================================================
# EDIT HISTORY:
# DATE                 | EDITED BY    | DESCRIPTION OF CHANGE
# ---------------------|--------------|----------------------------------------
# 2024-12-08 19:57:22  | Adam Compton | Initial creation.
# =============================================================================

# Guard to prevent multiple sourcing
if [[ -z "${BASH_PATH_SH_LOADED:-}" ]]; then
    declare -g BASH_PATH_SH_LOADED=true

    export GOPATH="${HOME}/go"
    export PATH="${HOME}/go/bin:/usr/local/go/bin:${PATH}:${HOME}/.local/bin"

    # macOS-specific paths
    # primarily for flock and dircolors
    if [[ "$(uname -s)" == "Darwin" ]]; then
        export PATH="/usr/local/opt/coreutils/libexec/gnubin:${PATH}"
        export PATH="/usr/local/opt/util-linux/bin:${PATH}"
        export PATH="/usr/local/opt/util-linux/sbin:${PATH}"
        export PATH="/opt/homebrew/bin:${PATH}"
        export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:${PATH}"
        export PATH="/opt/homebrew/opt/util-linux/bin:${PATH}"
        export PATH="/opt/homebrew/opt/util-linux/sbin:${PATH}"
    fi
fi
