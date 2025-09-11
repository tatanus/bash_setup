#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# NAME        : bash.visuals.sh
# DESCRIPTION : Provides spinner, progress bar, and timer functions for Bash.
# AUTHOR      : Adam Compton
# DATE CREATED: 2025-07-28
# =============================================================================
# EDIT HISTORY:
# DATE                 | EDITED BY    | DESCRIPTION OF CHANGE
# ---------------------|--------------|----------------------------------------
# 2025-07-28           | GPT          | Initial creation with spinner, progress bar, dots, and timer.
# =============================================================================

# Guard to prevent multiple sourcing
if [[ -z "${BASH_VISUALS_SH_LOADED:-}" ]]; then
    declare -g BASH_VISUALS_SH_LOADED=true

    # =============================================================================
    # Color Configuration
    # =============================================================================
    if command -v tput > /dev/null 2>&1; then
        light_green=$(tput setaf 2)
        light_blue=$(tput setaf 6)
        blue=$(tput setaf 4)
        light_red=$(tput setaf 1)
        yellow=$(tput setaf 3)
        orange=$(tput setaf 214 2> /dev/null || tput setaf 3)
        white=$(tput setaf 7)
        reset=$(tput sgr0)
    else
        light_green="\033[0;32m"
        light_blue="\033[1;36m"
        blue="\033[0;34m"
        light_red="\033[0;31m"
        yellow="\033[0;33m"
        orange="\033[1;33m"
        white="\033[0;37m"
        reset="\033[0m"
    fi

    # -----------------------------------------------------------------------------
    # Logging helpers – expected to be sourced from bash.aliases.sh or define here
    # -----------------------------------------------------------------------------
    function fail() {
        local timestamp
        timestamp=$(date +"[%Y-%m-%d %H:%M:%S]")
        printf "%s ${light_red}[- FAIL  ]${reset} %s\n" "${timestamp}" "$*" >&2
    }

    function pass() {
        local timestamp
        timestamp=$(date +"[%Y-%m-%d %H:%M:%S]")
        printf "%s ${light_green}[+ PASS  ]${reset} %s\n" "${timestamp}" "$*"
    }

    function info() {
        local timestamp
        timestamp=$(date +"[%Y-%m-%d %H:%M:%S]")
        printf "%s ${blue}[* INFO  ]${reset} %s\n" "${timestamp}" "$*"
    }

    function warn() {
        local timestamp
        timestamp=$(date +"[%Y-%m-%d %H:%M:%S]")
        printf "%s ${yellow}[! WARN  ]${reset} %s\n" "${timestamp}" "$*"
    }

    function debug() {
        local timestamp
        timestamp=$(date +"[%Y-%m-%d %H:%M:%S]")
        printf "%s ${orange}[# DEBUG ]${reset} %s\n" "${timestamp}" "$*"
    }

    ###############################################################################
    # Name: show_spinner
    # Short Description: Displays a spinner animation for a running command or PID.
    #
    # Long Description:
    #   This function will display a rotating spinner with elapsed time while a
    #   command is running or while a given process ID (PID) is still active.
    #
    # Parameters:
    #   $1 - PID (numeric) or a command string to execute
    #
    # Usage:
    #   show_spinner "sleep 5"
    #   long_running_command & show_spinner $!
    #
    # Returns:
    #   - Exit code of the monitored command
    ###############################################################################
    function show_spinner() {
        local arg="$1"
        local delay=0.1
        local spin="|/-\\"
        local start_time
        start_time=$(date +%s)
        local pid
        local is_command=0

        if [[ "${arg}" =~ ^[0-9]+$ ]]; then
            pid="${arg}"
        else
            is_command=1
            # shellcheck disable=SC2086  # Allow word splitting for command execution
            eval "${arg} &"
            pid=$!
        fi

        printf "Processing... (0s) "
        local i=0
        while kill -0 "${pid}" 2> /dev/null; do
            i=$(((i + 1) % 4))
            local elapsed=$(($(date +%s) - start_time))
            printf "\rProcessing... %s (%s seconds) " "${spin:${i}:1}" "${elapsed}"
            sleep "${delay}"
        done

        if [[ ${is_command} -eq 1 ]]; then
            wait "${pid}"
        fi

        local exit_code=$?
        local total_time=$(($(date +%s) - start_time))

        if [[ ${exit_code} -eq 0 ]]; then
            pass "Processing... Done! (${total_time}s)"
        else
            fail "Processing... Failed! (${total_time}s)"
        fi

        return "${exit_code}"
    }

    ###############################################################################
    # Name: show_progress_bar
    # Short Description: Displays a progress bar for a given percentage.
    #
    # Parameters:
    #   $1 - Percentage (0-100)
    #
    # Usage:
    #   for p in {0..100..10}; do
    #       show_progress_bar "$p"
    #       sleep 0.5
    #   done
    ###############################################################################
    function show_progress_bar() {
        local percent="${1:-0}"
        local width=50

        if ! [[ "${percent}" =~ ^[0-9]+$ ]]; then
            error "Progress value must be a number"
            return 1
        fi

        ((percent > 100)) && percent=100
        ((percent < 0)) && percent=0

        local filled=$((percent * width / 100))
        local empty=$((width - filled))

        # \r moves cursor to the beginning of the line
        printf "\rProgress: [%-*s] %3d%%" \
            "${width}" "$(printf "%0.s#" $(seq 1 "${filled}"))" "${percent}"

        if [[ "${percent}" -eq 100 ]]; then
            printf "\n"
            pass "Completed."
        fi
    }

    ###############################################################################
    # Name: show_dots
    # Short Description: Simple animated dots while a command or PID runs.
    #
    # Parameters:
    #   $1 - PID or command string
    #
    # Usage:
    #   show_dots "sleep 3"
    #   long_running_command & show_dots $!
    ###############################################################################
    function show_dots() {
        local arg="$1"
        local delay=0.5
        local pid
        local is_command=0

        if [[ "${arg}" =~ ^[0-9]+$ ]]; then
            pid="${arg}"
        else
            is_command=1
            eval "${arg} &"
            pid=$!
        fi

        printf "Processing"
        while kill -0 "${pid}" 2> /dev/null; do
            printf "."
            sleep "${delay}"
        done
        if [[ ${is_command} -eq 1 ]]; then
            wait "${pid}"
        fi
        printf "\n"
        pass "Processing complete"
    }

    ###############################################################################
    # Name: show_timer
    # Short Description: Displays elapsed time until a command finishes.
    #
    # Parameters:
    #   $1 - Command string
    #
    # Usage:
    #   show_timer "sleep 3"
    ###############################################################################
    function show_timer() {
        local cmd="$1"
        local start_time
        start_time=$(date +%s)
        info "Running: ${cmd}"
        eval "${cmd}"
        local exit_code=$?
        local elapsed=$(($(date +%s) - start_time))
        if [[ ${exit_code} -eq 0 ]]; then
            pass "Command finished in ${elapsed}s"
        else
            fail "Command failed after ${elapsed}s"
        fi
        return "${exit_code}"
    }

    ###############################################################################
    # strip_color
    #==============================
    # Removes ANSI color and control sequences from text or file.
    ###############################################################################
    function strip_color() {
        if [[ -z "$1" ]]; then
            error "No input provided to strip_color"
            return 1
        fi
        local ansi=$'\x1B\\[[0-9;]*[mK]'
        local control=$'[[:cntrl:]]'
        local nonprintable=$'[\x80-\xFF]'
        if [[ -f "$1" ]]; then
            LANG=C sed -E -e "s/${ansi}//g" -e "s/${control}//g" -e "s/${nonprintable}//g" "$1"
        else
            echo -e "$1" | LANG=C sed -E -e "s/${ansi}//g" -e "s/${control}//g" -e "s/${nonprintable}//g"
        fi
    }
fi
