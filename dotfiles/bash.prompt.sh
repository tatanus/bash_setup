#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

# =============================================================================
# NAME        : bash.prompt.sh
# DESCRIPTION : Customizes the Bash prompt with dynamic information such as
#               session names, IP addresses, and environment details.
# AUTHOR      : Adam Compton
# DATE CREATED: 2024-12-08 19:57:22
# =============================================================================
# EDIT HISTORY:
# DATE                 | EDITED BY    | DESCRIPTION OF CHANGE
# ---------------------|--------------|----------------------------------------
# 2024-12-08 19:57:22  | Adam Compton | Initial creation.
# 2025-04-24           | Adam Compton | Unified all comment blocks.
# =============================================================================

# Guard to prevent multiple sourcing
if [[ -z "${BASH_PROMPT_SH_LOADED:-}" ]]; then
    declare -g BASH_PROMPT_SH_LOADED=true

    # shellcheck shell=bash
    # Variables provided externally
    : "${white:=}" "${light_blue:=}" "${blue:=}" "${light_red:=}" "${yellow:=}" "${light_green:=}" "${orange:=}" "${reset:=}"

    # =============================================================================
    # Global Variables
    # =============================================================================
    PROMPT_LOCAL_IP="${PROMPT_LOCAL_IP:-Unavailable}"
    PROMPT_EXTERNAL_IP="${PROMPT_EXTERNAL_IP:-Unavailable}"
    LAST_LOCAL_IP_CHECK=0
    LAST_EXT_IP_CHECK=0

    ###############################################################################
    # validate_bash_dir
    #==============================
    # Ensures BASH_DIR is set, defaults to HOME if unset.
    #
    # Globals:
    #   BASH_DIR
    #
    # Returns:
    #   0 always. BASH_DIR will be set to a valid directory.
    ###############################################################################
    if [[ -z "${BASH_DIR:-}" ]]; then
        warn "BASH_DIR is not set; defaulting to HOME (${HOME})" >&2
        BASH_DIR="${HOME}"
    fi

    ###############################################################################
    # source_prompt_funcs
    #==============================
    # Sources bash.prompt_funcs.sh from BASH_DIR to provide helper functions.
    #
    # Globals:
    #   BASH_DIR
    #
    # Returns:
    #   0 if sourced, 1 if missing.
    ###############################################################################
    if [[ -f "${BASH_DIR}/bash.prompt_funcs.sh" ]]; then
        # shellcheck disable=SC1090
        source "${BASH_DIR}/bash.prompt_funcs.sh"
    else
        warn "${BASH_DIR}/bash.prompt_funcs.sh not found. Some prompt features may be unavailable." >&2
    fi

    ###############################################################################
    # gen_prompt
    #==============================
    # Builds the PS1 prompt with dynamic system info.
    #
    # Globals:
    #   PROMPT_LOCAL_IP
    #   PROMPT_EXTERNAL_IP
    #
    # Returns:
    #   Sets PS1 for the current session.
    ###############################################################################
    function gen_prompt() {
        # -------------------------------------------------------------------------
        # Build PS1 incrementally with sections
        # -------------------------------------------------------------------------
        PS1="\n\[${white}\]┏━"
        PS1+="$(check_git 2> /dev/null)"         # GIT STATUS
        PS1+="$(check_session 2> /dev/null)"     # SCREEN SESSION STATUS
        PS1+="$(check_kerb_ccache 2> /dev/null)" # KERBEROS CREDENTIAL CACHE
        PS1+="$(check_venv 2> /dev/null)"        # PYTHON VENV
        PS1+="\[${white}\]["

        # Date & time
        PS1+="\[${light_green}\]\D{%m-%d-%Y} \t"
        PS1+="\[${white}\]]━["

        # Local/internal IP addresses
        PS1+="${PROMPT_LOCAL_IP}"
        PS1+="\[${white}\]]━["

        # External IP
        PS1+="ext:\[${blue}\]${PROMPT_EXTERNAL_IP}"
        PS1+="\[${white}\]]━["

        # User@Host
        PS1+="\[${light_red}\]\u@\h"
        PS1+="\[${white}\]]\n"

        # Path
        PS1+="\[${white}\]┗━> [\[${yellow}\]\w\[${white}\]] \$ \[${reset}\]"

        export PS1="${PS1}"
    }

    ###############################################################################
    # preexec
    #==============================
    # Logs each command before execution with timestamp.
    #
    # Parameters:
    #   $1 - The command line about to be executed.
    #
    # Globals:
    #   None
    #
    # Returns:
    #   Outputs the command with a timestamp.
    ###############################################################################
    function preexec() {
        local date_time_stamp
        date_time_stamp=$(date +"[%D %T]")
        printf "\n%s # %s\n\n" "${date_time_stamp}" "$1"
    }

    # =============================================================================
    # Refresh IPs periodically
    # =============================================================================
    current_time=$(date +%s)

    # Refresh local IP every 5 minutes
    if ((current_time - LAST_LOCAL_IP_CHECK > 300)); then
        PROMPT_LOCAL_IP=$(get_local_ip 2> /dev/null || echo "Unavailable")
        LAST_LOCAL_IP_CHECK=${current_time}
    fi

    # Refresh external IP every 60 minutes
    if ((current_time - LAST_EXT_IP_CHECK > 3600)); then
        PROMPT_EXTERNAL_IP=$(get_external_ip 2> /dev/null || echo "Unavailable")
        LAST_EXT_IP_CHECK=${current_time}
    fi

    # =============================================================================
    # Source bash-preexec (optional)
    # =============================================================================
    if [[ -f "${BASH_DIR}/bash-preexec.sh" ]]; then
        # shellcheck disable=SC1090
        source "${BASH_DIR}/bash-preexec.sh"
    else
        warn "${BASH_DIR}/bash-preexec.sh not found. Preexec functionality may be unavailable." >&2
    fi

    # =============================================================================
    # Configure prompt refresh (integrate with bash-preexec if present)
    # =============================================================================
    # Configure prompt refresh: prefer precmd_functions; otherwise use PROMPT_COMMAND as an array
    if declare -p precmd_functions > /dev/null 2>&1; then
        # Append gen_prompt to precmd_functions if not already present
        _gp_add=1
        for _pc in "${precmd_functions[@]}"; do
            [[ "${_pc}" == "gen_prompt" ]] && _gp_add=0 && break
        done
        ((_gp_add)) && precmd_functions+=("gen_prompt")
        unset _pc _gp_add
    else
        _pc_old="${PROMPT_COMMAND-}" # capture any existing string without tripping set -u
        # shellcheck disable=SC2090
        _decl="$(declare -p PROMPT_COMMAND 2> /dev/null || true)"
        if [[ ! "${_decl}" =~ ^declare\ -a\ PROMPT_COMMAND= ]]; then
            # Re-declare as a global array, preserving old value (as one element) if present
            unset PROMPT_COMMAND || true
            declare -ga PROMPT_COMMAND=()
            [[ -n "${_pc_old}" ]] && PROMPT_COMMAND+=("${_pc_old}")
        fi
        unset _decl _pc_old

        # Append gen_prompt only if not already present
        _gp_add=1
        for _pc in "${PROMPT_COMMAND[@]}"; do
            [[ "${_pc}" == "gen_prompt" ]] && _gp_add=0 && break
        done
        ((_gp_add)) && PROMPT_COMMAND+=("gen_prompt")
        unset _pc _gp_add
    fi
fi
