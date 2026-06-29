#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

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

    # Debug mode (set to true or false). Keep DEFAULT=false so interactive
    # logins are quiet -- common_core's util.sh and util_config.sh emit
    # ~50 `debug` lines during library init, which floods the SSH banner.
    # Override with `DEBUG=true` in your own profile or before invoking a
    # specific command if you want to see the trace.
    export DEBUG="${DEBUG:-false}"

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

    ###############################################################################
    # _check_command
    #------------------------------------------------------------------------------
    # Purpose  : Check if a command is available in PATH
    # Usage    : _check_command <command>
    # Arguments:
    #   $1 : command - Name of the command to check
    # Returns  : 0 if available, 1 if not found
    ###############################################################################
    function _check_command() {
        if ! command -v "$1" &> /dev/null; then
            echo "$1 is not installed or not functional. Some functionality may not work."
            return 1
        fi
        return 0
    }

    # Apply LS_COLORS to the environment.
    # `dircolors -b` emits a stream of `export LS_COLORS=...` shell assignments
    # intended to be loaded into the current shell. The traditional idiom is
    # `eval "$(dircolors -b)"`, which the project bans. Bash 4+ lets us use
    # process substitution instead — `source <(...)` reads the assignments
    # through a FIFO without invoking eval, with identical effect.
    if _check_command "dircolors"; then
        # shellcheck source=/dev/null
        source <(dircolors -b)
    elif _check_command "gdircolors"; then
        alias dircolors="gdircolors"
        # shellcheck source=/dev/null
        source <(gdircolors -b)
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

    # PROXY is a dynamic command-prefix used by the installers / tool
    # scripts in this stack. Do NOT hard-code "proxychains4 -q " here:
    # exporting that unconditionally forces every child process (apt::,
    # ruby::, the installers) to route through proxychains even on hosts
    # with direct Internet, and common_core's `net::proxy_auto_detect`
    # honors an explicitly-set PROXY without auto-detecting. Leaving it
    # empty (or unset) lets the auto-detector pick the right value based
    # on actual reachability. To force proxychains in your interactive
    # shell, set `PROXY="proxychains4 -q"` in your local profile.
    export PROXY="${PROXY:-}"

    # Proxychains4 configuration file (still useful for tools that
    # invoke proxychains4 directly via a separate prefix variable).
    export PROXYCHAINS_CONFIG="/etc/proxychains4.conf"
fi
