#!/usr/bin/env bash
###############################################################################
# NAME         : bash-preexec.sh
# DESCRIPTION  : Bash support for ZSH-like `preexec` and `precmd` hooks.
# AUTHOR       : Adam Compton (project rewrite)
# DATE CREATED : 2026-06-25
###############################################################################
# EDIT HISTORY:
# DATE        | EDITED BY      | DESCRIPTION
# ------------|----------------|------------------------------------------------
# 2026-06-25  | Adam Compton   | Project rewrite from rcaloras/bash-preexec
#             |                | v0.5.0. Preserves public API
#             |                | (preexec_functions/precmd_functions arrays,
#             |                | BP_PIPESTATUS, __bp_delay_install,
#             |                | __bp_enable_subshells). Replaces upstream
#             |                | `eval '...'` block for prior-DEBUG-trap
#             |                | preservation with `source <(...)`. Drops
#             |                | bash 3.x compat (this stack mandates 4+).
#             |                | Applies project style: function name() form,
#             |                | proc-doc blocks, brace-quoted expansions.
###############################################################################
#
# OVERVIEW
# --------
# Two arrays the user (or other sourced helpers) populate:
#
#     preexec_functions+=(fn)   # called before each interactive command,
#                               # with the command string as $1
#     precmd_functions+=(fn)    # called before each prompt is rendered
#
# Optional convenience callbacks: define `preexec` and/or `precmd` as plain
# functions and they get registered automatically.
#
# Both hooks fire via two Bash mechanisms this file claims for itself:
#   * the DEBUG trap (drives preexec)
#   * PROMPT_COMMAND   (drives precmd)
#
# If anything else in the user's environment overrides either, this file
# will most likely break.  An existing DEBUG trap is preserved as a
# preexec callback (`__bp_original_debug_trap`); an existing PROMPT_COMMAND
# is sanitized and chained.
#
# STYLE NOTE
# ----------
# This file deliberately does NOT enable `set -uo pipefail` at the top.
# It is sourced into the user's interactive shell, and `set -u` / `set -o
# pipefail` would persist there and break every interactive session that
# touches an unset variable. All internal logic uses `${var:-}` defensive
# defaults so the upstream behavior under unset shells is preserved.
###############################################################################

# Refuse to load under non-Bash shells.
# Use POSIX-only constructs in this single line so a `sh` interpreter does
# not choke on bashisms before reaching the version check below.
# shellcheck disable=SC2292  # intentional [ ] for sh-compatible early gate
if [ -z "${BASH_VERSION:-}" ]; then
    # `return` is the sourced-path exit; `exit` is the executed-path exit.
    # shellcheck disable=SC2317  # only one arm fires depending on invocation
    return 1 2> /dev/null || exit 1
fi

# This stack mandates Bash 4+ throughout.
if ((BASH_VERSINFO[0] < 4)); then
    printf 'bash-preexec: Bash 4+ required (have %s)\n' "${BASH_VERSION}" >&2
    return 1
fi

#===============================================================================
# Source guard
#===============================================================================
if [[ -n "${bash_preexec_imported:-}" || -n "${__bp_imported:-}" ]]; then
    return 0
fi
bash_preexec_imported="defined"

# Legacy alias retained for any third-party code that read it.
# shellcheck disable=SC2034  # exported for backward compatibility
__bp_imported="${bash_preexec_imported}"

#===============================================================================
# Public state
#===============================================================================

# Last command's exit status and last argument, captured before any
# precmd/preexec hook runs so callbacks can observe them as if they were
# the first thing the shell saw post-command.
__bp_last_ret_value="${?}"
__bp_last_argument_prev_command="${_}"

# Snapshot of PIPESTATUS at the moment a precmd fires (the real
# PIPESTATUS is clobbered by anything the hooks do). Exposed to callbacks.
# shellcheck disable=SC2034  # consumed by external preexec/precmd callbacks
BP_PIPESTATUS=("${PIPESTATUS[@]}")

# Recursion guards. Each hook bumps its counter on entry and (via `local`)
# unbumps on exit so nested invocations (e.g. one precmd whose PROMPT_COMMAND
# emission would re-fire precmds) are short-circuited.
__bp_inside_precmd=0
__bp_inside_preexec=0

# "Interactive mode" flag. Set by `__bp_interactive_mode` (which runs as
# part of PROMPT_COMMAND), cleared by `__bp_preexec_invoke_exec` once an
# interactive command is detected. Tells the DEBUG trap whether the next
# command is the user's input or shell housekeeping.
__bp_preexec_interactive_mode=""

# Two hook arrays. Users append:
#     preexec_functions+=(my_preexec_fn)
#     precmd_functions+=(my_precmd_fn)
declare -a precmd_functions
declare -a preexec_functions

# String injected into PROMPT_COMMAND by __bp_install_after_session_init.
# When the user hits Enter for the first time, this string runs, snapshots
# the current DEBUG trap, clears it, and calls __bp_install.
__bp_install_string=$'__bp_trap_string="$(trap -p DEBUG)"\ntrap - DEBUG\n__bp_install'

#===============================================================================
# Internal helpers
#===============================================================================

###############################################################################
# __bp_require_not_readonly
#------------------------------------------------------------------------------
# Purpose  : Fail if any of the named variables are readonly. bash-preexec
#            must be able to assign to PROMPT_COMMAND, HISTCONTROL, and
#            HISTTIMEFORMAT; if they're readonly, installation is impossible.
# Usage    : __bp_require_not_readonly PROMPT_COMMAND HISTCONTROL ...
# Arguments: $@ - variable names to test
# Returns  : 0 if all writable, 1 if any readonly
###############################################################################
function __bp_require_not_readonly() {
    local var
    for var in "$@"; do
        if ! (unset "${var}" 2> /dev/null); then
            printf 'bash-preexec requires write access to %s\n' "${var}" >&2
            return 1
        fi
    done
}

###############################################################################
# __bp_adjust_histcontrol
#------------------------------------------------------------------------------
# Purpose  : Strip `ignorespace` from HISTCONTROL and substitute `ignoredups`
#            for `ignoreboth`. preexec uses `builtin history 1` to recover
#            the just-executed command line; commands silently dropped from
#            history would be invisible to it.
# Usage    : __bp_adjust_histcontrol
# Returns  : 0 always
# Globals  : HISTCONTROL (mutates)
###############################################################################
function __bp_adjust_histcontrol() {
    local histcontrol="${HISTCONTROL:-}"
    histcontrol="${histcontrol//ignorespace/}"
    if [[ "${histcontrol}" == *"ignoreboth"* ]]; then
        histcontrol="ignoredups:${histcontrol//ignoreboth/}"
    fi
    export HISTCONTROL="${histcontrol}"
}

###############################################################################
# __bp_trim_whitespace
#------------------------------------------------------------------------------
# Purpose  : Trim leading/trailing whitespace from $2; write result to the
#            variable named by $1 (using printf -v).
# Usage    : __bp_trim_whitespace dest "  text  "
# Arguments:
#   $1 : destination variable name
#   $2 : input text
# Returns  : 0 always
###############################################################################
function __bp_trim_whitespace() {
    local var="${1:?}"
    local text="${2:-}"
    text="${text#"${text%%[![:space:]]*}"}"
    text="${text%"${text##*[![:space:]]}"}"
    printf -v "${var}" '%s' "${text}"
}

###############################################################################
# __bp_sanitize_string
#------------------------------------------------------------------------------
# Purpose  : Trim whitespace AND strip leading/trailing semicolons from $2;
#            write result to the variable named by $1. Used to normalize the
#            existing PROMPT_COMMAND so we can append our own hooks cleanly.
# Usage    : __bp_sanitize_string dest "; foo; bar ;"
# Arguments:
#   $1 : destination variable name
#   $2 : input text
# Returns  : 0 always
###############################################################################
function __bp_sanitize_string() {
    local var="${1:?}"
    local text="${2:-}"
    local sanitized
    __bp_trim_whitespace sanitized "${text}"
    sanitized="${sanitized%;}"
    sanitized="${sanitized#;}"
    __bp_trim_whitespace sanitized "${sanitized}"
    printf -v "${var}" '%s' "${sanitized}"
}

###############################################################################
# __bp_set_ret_value
#------------------------------------------------------------------------------
# Purpose  : Restore `$?` (and optionally `$_`) to a previously captured
#            value so a precmd/preexec callback sees the same $?/$_ the user
#            would have seen at the prompt.
# Usage    : __bp_set_ret_value "${last_rc}" "${last_arg}"
# Arguments:
#   $1 : return code to restore as $?
#   $2 : (optional) value for $_  -- bash exposes the last argument of the
#        previous command as $_; we re-invoke a builtin that touches it
#        only by side-effect, which is why we leave $2 unread inside.
# Returns  : ${1:+$1}, i.e. $1 if non-empty, else 0
###############################################################################
function __bp_set_ret_value() {
    return ${1:+"$1"}
}

###############################################################################
# __bp_in_prompt_command
#------------------------------------------------------------------------------
# Purpose  : Return success if $1 (typically BASH_COMMAND inside the DEBUG
#            trap) is a substring of any segment of PROMPT_COMMAND. Lets the
#            DEBUG trap skip firing preexec for commands the shell itself
#            generated as part of rendering the prompt.
# Usage    : __bp_in_prompt_command "${BASH_COMMAND}" && return
# Arguments:
#   $1 : candidate command string
# Returns  : 0 if matched, 1 otherwise
###############################################################################
function __bp_in_prompt_command() {
    local prompt_command_array
    local IFS=$'\n;'
    # In bash 5.1+ PROMPT_COMMAND can be an array; expand with [*] to merge.
    read -rd '' -a prompt_command_array <<< "${PROMPT_COMMAND[*]:-}"

    local trimmed_arg
    __bp_trim_whitespace trimmed_arg "${1:-}"

    local command trimmed_command
    for command in "${prompt_command_array[@]:-}"; do
        __bp_trim_whitespace trimmed_command "${command}"
        if [[ "${trimmed_command}" == "${trimmed_arg}" ]]; then
            return 0
        fi
    done
    return 1
}

###############################################################################
# __bp_interactive_mode
#------------------------------------------------------------------------------
# Purpose  : Mark "we are at the prompt, the next interactive command is
#            user-typed". Installed as the LAST entry in PROMPT_COMMAND so it
#            runs after every other precmd has finished.
# Usage    : (PROMPT_COMMAND-injected; not called directly)
# Returns  : 0 always
###############################################################################
function __bp_interactive_mode() {
    __bp_preexec_interactive_mode="on"
}

#===============================================================================
# Precmd loop (runs via PROMPT_COMMAND)
#===============================================================================

###############################################################################
# __bp_precmd_invoke_cmd
#------------------------------------------------------------------------------
# Purpose  : Walk precmd_functions and invoke each one. Snapshots $?, $_,
#            and PIPESTATUS first so each callback sees the values that
#            held at the moment the previous command finished.
# Usage    : (PROMPT_COMMAND-injected; not called directly)
# Returns  : 0; restores $? via __bp_set_ret_value at the end
###############################################################################
function __bp_precmd_invoke_cmd() {
    # MUST be the first thing in this function: $? and PIPESTATUS are
    # clobbered the instant any other command runs.
    # shellcheck disable=SC2034  # BP_PIPESTATUS is part of the public API
    __bp_last_ret_value="$?" BP_PIPESTATUS=("${PIPESTATUS[@]}")

    # Recursion guard.
    if ((__bp_inside_precmd > 0)); then
        return
    fi
    local __bp_inside_precmd=1

    local precmd_function
    for precmd_function in "${precmd_functions[@]}"; do
        # Skip slots that aren't actually defined functions.
        if type -t "${precmd_function}" 1> /dev/null; then
            __bp_set_ret_value "${__bp_last_ret_value}" "${__bp_last_argument_prev_command}"
            # Quoted to keep callback name intact under any IFS.
            "${precmd_function}"
        fi
    done

    __bp_set_ret_value "${__bp_last_ret_value}"
}

#===============================================================================
# Preexec loop (runs via DEBUG trap)
#===============================================================================

###############################################################################
# __bp_preexec_invoke_exec
#------------------------------------------------------------------------------
# Purpose  : DEBUG-trap handler. Decides whether the about-to-run command
#            is actually a user-typed interactive command (vs. something
#            the shell is doing internally) and, if so, fires every
#            preexec_function with the command line as $1.
# Usage    : (DEBUG-trap-installed; not called directly)
# Arguments:
#   $1 : the value of $_ at trap time (saved for $_ restoration)
# Returns  : 0 normally; with extdebug enabled, a non-zero return from any
#            preexec function suppresses the user's command from running.
###############################################################################
function __bp_preexec_invoke_exec() {
    # Stash $_ for restoration once the preexec loop finishes.
    __bp_last_argument_prev_command="${1:-}"

    if ((__bp_inside_preexec > 0)); then
        return
    fi
    local __bp_inside_preexec=1

    # __bp_delay_install lets bats (and other harnesses) source us without
    # auto-installing; in that mode we still want preexec to fire.
    if [[ ! -t 1 && -z "${__bp_delay_install:-}" ]]; then
        return
    fi

    # Completion or `bind -x` keybinding -- never user-issued.
    if [[ -n "${COMP_POINT:-}" || -n "${READLINE_POINT:-}" ]]; then
        return
    fi

    # The flag is "off" between commands and "on" only between prompt-render
    # and next-command-run. If it's off here, the DEBUG trap is firing for
    # shell-internal reasons (PS1 expansion, etc.) -- skip.
    if [[ -z "${__bp_preexec_interactive_mode:-}" ]]; then
        return
    else
        # Subshell case: the prompt won't re-render before the next command,
        # so leave the flag set so chained subshell commands all fire preexec.
        # Example: `(sleep 1; sleep 2)` -- second `sleep` should still fire.
        if [[ 0 -eq "${BASH_SUBSHELL:-0}" ]]; then
            __bp_preexec_interactive_mode=""
        fi
    fi

    # Skip if BASH_COMMAND is itself part of PROMPT_COMMAND.
    if __bp_in_prompt_command "${BASH_COMMAND:-}"; then
        __bp_preexec_interactive_mode=""
        return
    fi

    # Recover the actual command line text from history. `builtin history 1`
    # prints the most recent entry; sed strips the leading `  N  ` prefix.
    # LC_ALL=C avoids locale-dependent regex behavior; HISTTIMEFORMAT=''
    # avoids the optional timestamp prefix.
    local this_command
    this_command=$(
        export LC_ALL=C
        HISTTIMEFORMAT='' builtin history 1 | sed '1 s/^ *[0-9][0-9]*[* ] //'
    )

    if [[ -z "${this_command}" ]]; then
        return
    fi

    local preexec_function
    local preexec_function_ret_value
    local preexec_ret_value=0
    for preexec_function in "${preexec_functions[@]:-}"; do
        if type -t "${preexec_function}" 1> /dev/null; then
            __bp_set_ret_value "${__bp_last_ret_value:-}"
            "${preexec_function}" "${this_command}"
            preexec_function_ret_value="$?"
            # First non-zero return wins (extdebug uses this to veto the command).
            if [[ "${preexec_function_ret_value}" != 0 ]]; then
                preexec_ret_value="${preexec_function_ret_value}"
            fi
        fi
    done

    # Restore $_ and propagate the non-zero return (if any). Under
    # `shopt -s extdebug`, a non-zero return here causes Bash to abort
    # the user's command.
    __bp_set_ret_value "${preexec_ret_value}" "${__bp_last_argument_prev_command}"
}

#===============================================================================
# Installation
#===============================================================================

###############################################################################
# __bp_install
#------------------------------------------------------------------------------
# Purpose  : Wire up the DEBUG trap and PROMPT_COMMAND hook in the live
#            shell. Called from PROMPT_COMMAND on first prompt render.
#            Preserves any pre-existing DEBUG trap as
#            __bp_original_debug_trap and appends it to preexec_functions.
# Usage    : (PROMPT_COMMAND-injected by __bp_install_after_session_init)
# Returns  : 0 on success, 1 if already installed
###############################################################################
function __bp_install() {
    # Already installed?
    if [[ "${PROMPT_COMMAND[*]:-}" == *"__bp_precmd_invoke_cmd"* ]]; then
        return 1
    fi

    # Claim the DEBUG trap.
    trap '__bp_preexec_invoke_exec "$_"' DEBUG

    # Preserve any pre-existing DEBUG trap. The snapshot was taken inside
    # __bp_install_string with `trap -p DEBUG`, which emits a single line:
    #     trap -- 'BODY' DEBUG
    # The sed regex extracts BODY (everything between the outermost single
    # quotes). We then define __bp_original_debug_trap so its body IS BODY.
    local prior_trap
    # shellcheck disable=SC2001  # the substitution is more readable than ${//} here
    prior_trap=$(sed "s/[^']*'\(.*\)'[^']*/\1/" <<< "${__bp_trap_string:-}")
    unset __bp_trap_string

    if [[ -n "${prior_trap}" ]]; then
        # Define the preservation function WITHOUT eval. `source <(...)`
        # reads a here-doc-like stream through a FIFO and treats it as
        # shell input -- equivalent to eval for this use, no eval keyword.
        # shellcheck source=/dev/null
        source <(printf 'function __bp_original_debug_trap() {\n    %s\n}\n' "${prior_trap}")
        preexec_functions+=(__bp_original_debug_trap)
    fi

    __bp_adjust_histcontrol

    # Issue #25 (upstream): debug trap in subshells can kill backgrounded
    # subshell commands like `(pwd)&`. Off by default; opt in via
    # __bp_enable_subshells.
    if [[ -n "${__bp_enable_subshells:-}" ]]; then
        set -o functrace > /dev/null 2>&1
        shopt -s extdebug > /dev/null 2>&1
    fi

    # Sanitize the existing PROMPT_COMMAND so our hooks slot in cleanly.
    local existing_prompt_command="${PROMPT_COMMAND:-}"
    existing_prompt_command="${existing_prompt_command//${__bp_install_string}/:}"
    existing_prompt_command="${existing_prompt_command//$'\n':$'\n'/$'\n'}"
    existing_prompt_command="${existing_prompt_command//$'\n':;/$'\n'}"
    __bp_sanitize_string existing_prompt_command "${existing_prompt_command}"
    if [[ "${existing_prompt_command:-:}" == ":" ]]; then
        existing_prompt_command=
    fi

    # Hook our precmd loop into PROMPT_COMMAND.
    PROMPT_COMMAND='__bp_precmd_invoke_cmd'
    PROMPT_COMMAND+=${existing_prompt_command:+$'\n'${existing_prompt_command}}
    # Bash 5.1+ supports PROMPT_COMMAND as an array. Use array append form
    # there; older bashes get a newline-joined scalar.
    if ((BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1))); then
        PROMPT_COMMAND+=('__bp_interactive_mode')
    else
        # shellcheck disable=SC2179  # PROMPT_COMMAND is not an array on bash <= 5.0
        PROMPT_COMMAND+=$'\n__bp_interactive_mode'
    fi

    # Auto-register the convenience callbacks `preexec` and `precmd` if
    # the user (or another sourced file) has defined them as plain fns.
    precmd_functions+=(precmd)
    preexec_functions+=(preexec)

    # Fire the precmd loop once now so callbacks see the initial state,
    # and mark interactive mode so the very first command fires preexec.
    __bp_precmd_invoke_cmd
    __bp_interactive_mode
}

###############################################################################
# __bp_install_after_session_init
#------------------------------------------------------------------------------
# Purpose  : Two-step installation. Rather than calling __bp_install
#            directly (which would happen during shell init, before user
#            customizations have settled), inject a one-shot string into
#            PROMPT_COMMAND that snapshots the current DEBUG trap and
#            then calls __bp_install on the user's first Enter press.
# Usage    : Called automatically from the entry point at the bottom of
#            this file, unless __bp_delay_install is set.
# Returns  : 0 normally; 1 if any required variable is readonly
###############################################################################
function __bp_install_after_session_init() {
    __bp_require_not_readonly PROMPT_COMMAND HISTCONTROL HISTTIMEFORMAT || return

    local sanitized_prompt_command
    __bp_sanitize_string sanitized_prompt_command "${PROMPT_COMMAND:-}"
    if [[ -n "${sanitized_prompt_command}" ]]; then
        # shellcheck disable=SC2178  # PROMPT_COMMAND is not an array on bash <= 5.0
        PROMPT_COMMAND=${sanitized_prompt_command}$'\n'
    fi
    # shellcheck disable=SC2179  # PROMPT_COMMAND is not an array on bash <= 5.0
    PROMPT_COMMAND+=${__bp_install_string}
}

#===============================================================================
# Entry point
#===============================================================================
# Test harnesses set __bp_delay_install=1 before sourcing so they can drive
# the install lifecycle by hand. In all other cases, auto-install.
if [[ -z "${__bp_delay_install:-}" ]]; then
    __bp_install_after_session_init
fi
