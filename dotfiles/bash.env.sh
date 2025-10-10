#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# NAME        : bash.env.sh
# DESCRIPTION : Environment setup for Bash
# AUTHOR      : Adam Compton
# DATE CREATED: 2024-12-08 19:57:22
# =============================================================================
# EDIT HISTORY:
# DATE                 | EDITED BY    | DESCRIPTION OF CHANGE
# ---------------------|--------------|----------------------------------------
# 2024-12-08 19:57:22  | Adam Compton | Initial creation.
# =============================================================================

# Guard to prevent multiple sourcing
if [[ -z "${BASH_ENV_SH_LOADED:-}" ]]; then
    declare -g BASH_ENV_SH_LOADED=true

    # Debug mode (set to true or false)
    export DEBUG=true

    # pass/fail/true/fall variables
    export PASS=0
    export FAIL=1

    # define default editor
    export EDITOR="vim"

    # enable LS colored output
    export CLICOLOR=1

    # define colors for macOS
    export LSCOLORS=exfxcxdxbxegedabagacxx

    # define colors for Linux
    export LS_COLORS="di=34:ln=35:so=32:pi=33:ex=31:bd=34:cd=34:su=0;41:sg=0;46:tw=0;42:ow=33"

    # Helper function: Check command availability
    function _check_command() {
        command -v "$1" &> /dev/null
        if [[ $? -ne 0 ]]; then
            echo "$1 is not installed or not functional. Some functionality may not work."
            return 1
        fi
        return 0
    }

    # Apply LS_COLORS to the environment
    # Apply dircolors if available
    if _check_command "dircolors"; then
        eval "$(dircolors -b)"
    elif _check_command "gdircolors"; then
        alias dircolors="gdircolors"
        eval "$(gdircolors -b)"
    else
        echo "Neither dircolors nor gdircolors is available. Skipping color setup."
    fi

    # If you want to use LS_COLORS in completion (for example, with GNU Readline):
    if [[ $- == *i* ]]; then
        if [[ -n "${BASH_VERSION}" ]]; then
            bind 'set colored-stats on'
        fi
    fi

    # configure bat  (bat > cat)
    export BAT_PAGER="less -R"
    export BAT_THEME="ansi"

    # Enable proxychains4 for certain commands (true/false)
    export PROXY="proxychains4 -q "

    # Proxychains4 configuration file
    export PROXYCHAINS_CONFIG="/etc/proxychains4.conf"
fi
