#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# NAME        : bash.aliases.sh
# DESCRIPTION : A collection of useful aliases and functions for Bash.
# AUTHOR      : Adam Compton
# DATE CREATED: 2024-12-08 19:57:22
# =============================================================================
# EDIT HISTORY:
# DATE                 | EDITED BY    | DESCRIPTION OF CHANGE
# ---------------------|--------------|----------------------------------------
# 2024-12-08 19:57:22  | Adam Compton | Initial creation.
# =============================================================================

# Guard to prevent multiple sourcing
if [[ -z "${BASH_ALIAS_SH_LOADED:-}" ]]; then
    declare -g BASH_ALIAS_SH_LOADED=true

    ###############################################################################
    # Source additional functions if available
    ###############################################################################
    if [[ -f "${BASH_DIR}/bash.funcs.sh" ]]; then
        # shellcheck disable=SC1090
        source "${BASH_DIR}/bash.funcs.sh"
    else
        warn "bash.funcs.sh not found in ${BASH_DIR}, some features may be unavailable."
    fi

    ###############################################################################
    # Aliases setup
    ###############################################################################

    # Alias for ncat (preferred nc replacement)
    if check_command "ncat"; then
        # (interactive only)
        if [[ $- == *i* ]]; then
            alias nc="ncat"
            debug "Alias set: nc -> ncat"
        fi
    fi

    # macOS-specific aliases
    if [[ "$(_get_os)" == "macos" ]]; then
        # Use GNU sed if available
        if check_command "gsed"; then
            # (interactive only)
            if [[ $- == *i* ]]; then
                alias sed="gsed"
                debug "Alias set: sed -> gsed"
            fi
        fi
    fi

    # Always enable colored grep output
    alias grep='grep --color=auto'

    # macOS: Prefer ggrep for extended functionality
    if [[ "$(_get_os)" == "macos" ]]; then
        if check_command "ggrep"; then
            # (interactive only)
            if [[ $- == *i* ]]; then
                alias grep="ggrep --color=auto"
                debug "Alias set: grep -> ggrep --color=auto"
            fi
        fi
    fi

    # Replace ls with eza if available
    if check_command "eza"; then
        # (interactive only)
        if [[ $- == *i* ]]; then
            alias ls='convert_ls_to_eza'
            debug "Alias set: ls -> convert_ls_to_eza"
        fi
    fi

    ###############################################################################
    # bat / batcat setup for colorized `cat`
    ###############################################################################
    if command -v bat &> /dev/null; then
        alias cat='bat --paging=never --style=plain --theme=ansi'
        debug "Alias set: cat -> bat"
    elif command -v batcat &> /dev/null; then
        alias cat='batcat --paging=never --style=plain --theme=ansi'
        debug "Alias set: cat -> batcat"
    else
        warn "Neither 'bat' nor 'batcat' installed. Using plain cat."
    fi

    ###############################################################################
    # realpath fallback
    # If no realpath command, use readlink -f (Linux)
    ###############################################################################
    if ! command -v realpath &> /dev/null && command -v readlink &> /dev/null; then
        alias realpath='readlink -f'
        debug "Alias set: realpath -> readlink -f"
    fi

    ###############################################################################
    # proxychains alias
    ###############################################################################
    if check_command "proxychains4"; then
        alias PROXY="proxychains4 -q"
        debug "Alias set: PROXY -> proxychains4 -q"
    fi

    ###############################################################################
    # curl customizations (only if available)
    ###############################################################################
    if check_command "curl"; then
        alias myip="\${PROXY} curl ifconfig.me/ip"
        alias curl='curl -A "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36" -k'
        debug "Alias set: curl with custom UA and myip alias"
    fi

    ###############################################################################
    # Common alias adjustments
    ###############################################################################
    alias dig='dig +short'
    alias wget='wget -c'
    alias listen="netstat -tupan | grep LISTEN"

    ###############################################################################
    # file_hogs
    #==============================
    # Lists the top N largest files (default: 10) under the current directory.
    # Output is sorted by size in a human-readable format.
    #
    # Usage:
    #   file_hogs           # Show top 10 largest files
    #   file_hogs 25        # Show top 25 largest files
    #
    # Returns:
    #   0 on success
    #   1 on invalid argument or failure
    ###############################################################################
    function file_hogs() {
        local count=10

        # ---------------------------------------------------------------------
        # Validate optional argument
        # ---------------------------------------------------------------------
        if [[ $# -gt 0 ]]; then
            if [[ "$1" =~ ^[0-9]+$ ]] && [[ "$1" -gt 0 ]]; then
                count="$1"
            else
                fail "Invalid argument. Usage: file_hogs [positive_integer]"
                return 1
            fi
        fi

        # ---------------------------------------------------------------------
        # Find and list largest files
        # ---------------------------------------------------------------------
        if ! command -v find &> /dev/null || ! command -v du &> /dev/null; then
            fail "Required commands 'find' and 'du' are missing."
            return 1
        fi

        find . -type f -exec du -h {} + 2> /dev/null | sort -hr | head -n "${count}"
    }
fi
