#!/usr/bin/env bash
# shellcheck disable=SC2154 # PASS, FAIL are defined by common_core when sourced
###############################################################################
# NAME         : bash.funcs.sh
# DESCRIPTION  : A collection of useful functions for Bash.
# AUTHOR       : Adam Compton
# DATE CREATED : 2024-12-08 19:57:22
###############################################################################
# EDIT HISTORY:
# DATE       | EDITED BY    | DESCRIPTION
# -----------|--------------|-----------------------------------------------
# 2024-12-08 | Adam Compton | Initial creation.
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Guard to Prevent Multiple Sourcing
#===============================================================================
if [[ -z "${BASH_FUNCS_SH_LOADED:-}" ]]; then
    declare -g BASH_FUNCS_SH_LOADED=true

    #===============================================================================
    # Fallback Logging Functions (only define if not already declared)
    #===============================================================================
    if ! declare -F info > /dev/null 2>&1; then
        function info() { printf '[INFO ] %s\n' "${1}";  }
    fi
    if ! declare -F warn > /dev/null 2>&1; then
        function warn() { printf '[WARN ] %s\n' "${1}";  }
    fi
    if ! declare -F error > /dev/null 2>&1; then
        function error() { printf '[ERROR] %s\n' "${1}";  }
    fi
    if ! declare -F fail > /dev/null 2>&1; then
        function fail() { printf '[FAIL ] %s\n' "${1}";  }
    fi

    ###############################################################################
    # history_search
    #------------------------------------------------------------------------------
    # Purpose  : Searches ~/.config/bash/log/bash_history.log for entries within
    #            ±N minutes of a given timestamp.
    # Usage    : history_search "YYYY-MM-DD HH:MM:SS" [range_minutes]
    # Arguments:
    #   $1 : Target timestamp string (format: YYYY-MM-DD HH:MM:SS)
    #   $2 : Range in minutes (default: 10)
    # Returns  : Prints matching log lines to stdout, or 1 on error.
    # Globals  : BASH_LOG_DIR
    ###############################################################################
    function history_search() {
        local input_time="${1:-}"
        local range_minutes="${2:-10}"
        local log_file target_epoch range_seconds start_epoch end_epoch

        if [[ -z "${BASH_LOG_DIR:-}" ]]; then
            log_file="${HOME}/.combined_history.log"
        else
            log_file="${BASH_LOG_DIR}/bash_history.log"
        fi

        if [[ -z "${input_time}" ]]; then
            fail "Usage: history_search \"YYYY-MM-DD HH:MM:SS\" [range_minutes]"
            return "${FAIL}"
        fi
        if [[ ! -f "${log_file}" ]]; then
            error "Log file not found: ${log_file}"
            return "${FAIL}"
        fi
        if ! target_epoch=$(date -d "${input_time}" +%s 2> /dev/null); then
            fail "Invalid timestamp format. Use YYYY-MM-DD HH:MM:SS"
            return "${FAIL}"
        fi

        range_seconds=$((range_minutes * 60))
        start_epoch=$((target_epoch - range_seconds))
        end_epoch=$((target_epoch + range_seconds))

        awk -v start="${start_epoch}" -v end="${end_epoch}" '
        {
            match($0, /\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]/, ts)
            if (ts[0] != "") {
                gsub(/\[|\]/, "", ts[0])
                log_epoch = mktime(gensub(/[-:]/, " ", "g", ts[0]))
                if (log_epoch >= start && log_epoch <= end) {
                    print $0
                }
            }
        }' "${log_file}"
    }

    ###############################################################################
    # _get_os
    #------------------------------------------------------------------------------
    # Purpose  : Detect the current operating system.
    # Returns  : OS identifier: macos, ubuntu, wsl, windows, linux, or unknown.
    ###############################################################################
    function _get_os() {
        local uname_output
        uname_output="$(uname -s)"

        if [[ "${uname_output}" == "Darwin" ]]; then
            printf '%s\n' "macos"
            return "${PASS}"
        fi
        if grep -qi Microsoft /proc/version 2> /dev/null; then
            printf '%s\n' "wsl"
            return "${PASS}"
        fi

        case "${uname_output}" in
            CYGWIN* | MINGW* | MSYS*)
                printf '%s\n' "windows"
                return "${PASS}"
                ;;
            *)  ;;
        esac

        if [[ "${uname_output}" == "Linux" ]]; then
            if [[ -f /etc/os-release ]] && grep -qi "ubuntu" /etc/os-release; then
                printf '%s\n' "ubuntu"
                return "${PASS}"
            fi
            printf '%s\n' "linux"
            return "${PASS}"
        fi
        printf '%s\n' "unknown"
        return "${PASS}"
    }

    ###############################################################################
    # _get_macos_version
    #------------------------------------------------------------------------------
    # Purpose  : Retrieve macOS version using `sw_vers -productVersion`.
    # Returns  : Version string or 1 on failure.
    ###############################################################################
    function _get_macos_version() {
        if [[ "$(_get_os)" != "macos" ]]; then
            fail "Not running on macOS."
            return "${FAIL}"
        fi
        if ! command -v sw_vers > /dev/null 2>&1; then
            fail "Missing sw_vers command. Cannot detect macOS version."
            return "${FAIL}"
        fi
        local macos_version
        macos_version="$(sw_vers -productVersion 2> /dev/null || true)"
        if [[ -z "${macos_version}" ]]; then
            fail "Could not retrieve macOS version."
            return "${FAIL}"
        fi
        printf '%s\n' "${macos_version}"
        return "${PASS}"
    }

    ###############################################################################
    # _get_ubuntu_version
    #------------------------------------------------------------------------------
    # Purpose  : Retrieve Ubuntu version using /etc/os-release or lsb_release.
    # Returns  : Version string or 1 on failure.
    ###############################################################################
    function _get_ubuntu_version() {
        if [[ "$(_get_os)" != "ubuntu" ]]; then
            fail "Not running on Ubuntu."
            return "${FAIL}"
        fi
        local ubuntu_version=""
        if [[ -f /etc/os-release ]]; then
            ubuntu_version="$(grep -oP 'VERSION_ID="\K[^"]+' /etc/os-release || true)"
        elif command -v lsb_release > /dev/null 2>&1; then
            ubuntu_version="$(lsb_release -rs 2> /dev/null || true)"
        fi
        if [[ -z "${ubuntu_version}" ]]; then
            fail "Unable to determine Ubuntu version."
            return "${FAIL}"
        fi
        printf '%s\n' "${ubuntu_version}"
        return "${PASS}"
    }

    ###############################################################################
    # _get_windows_version
    #------------------------------------------------------------------------------
    # Purpose  : Retrieve Windows version using `cmd.exe /c ver`.
    # Returns  : Version string or 1 on failure.
    ###############################################################################
    function _get_windows_version() {
        local current_os
        current_os="$(_get_os)"

        if [[ "${current_os}" != "windows" ]]; then
            fail "Not running on Windows (Cygwin/Mingw/MSYS)."
            return "${FAIL}"
        fi
        if ! command -v cmd.exe > /dev/null 2>&1; then
            fail "cmd.exe not found. Cannot detect Windows version."
            return "${FAIL}"
        fi
        local ver_output windows_version
        ver_output="$(cmd.exe /c "ver" 2> /dev/null || true)"
        windows_version="$(printf '%s\n' "${ver_output}" | grep -oP '\[Version\s\K[^\]]+' || true)"
        if [[ -z "${windows_version}" ]]; then
            fail "Could not retrieve Windows version from cmd.exe."
            return "${FAIL}"
        fi
        printf '%s\n' "${windows_version}"
        return "${PASS}"
    }

    ###############################################################################
    # _get_linux_version
    #------------------------------------------------------------------------------
    # Purpose  : Retrieve generic Linux version.
    # Returns  : Version string or empty if unknown.
    ###############################################################################
    function _get_linux_version() {
        if [[ "$(_get_os)" != "linux" ]]; then
            printf '%s\n' ""
            return "${PASS}"
        fi
        if [[ ! -f /etc/os-release ]]; then
            printf '%s\n' ""
            return "${PASS}"
        fi
        grep -oP 'VERSION_ID="\K[^"]+' /etc/os-release || true
    }

    ###############################################################################
    # check_command
    #------------------------------------------------------------------------------
    # Purpose  : Check for a required command and suggest installation if missing.
    # Arguments:
    #   $1 : Command name to validate.
    # Returns  : PASS (0) if found, FAIL (1) if missing.
    ###############################################################################
    function check_command() {
        local cmd="${1:-}"
        if [[ -z "${cmd}" ]]; then
            error "Usage: check_command <command>"
            return "${FAIL}"
        fi
        if ! command -v "${cmd}" > /dev/null 2>&1; then
            local os install_hint
            os="$(_get_os)"
            case "${os}" in
                macos) install_hint="brew install ${cmd}" ;;
                ubuntu | wsl) install_hint="sudo apt-get install ${cmd}" ;;
                *) install_hint="(install ${cmd} manually)" ;;
            esac
            warn "[${cmd}] is not installed. Suggested: ${install_hint}"
            return "${FAIL}"
        fi
        return "${PASS}"
    }

    ###############################################################################
    # convert_ls_to_eza
    #------------------------------------------------------------------------------
    # Purpose  : Converts an ls command to an equivalent eza command with options.
    # Usage    : convert_ls_to_eza [ls options/args]
    ###############################################################################
    function convert_ls_to_eza() {
        local cmd=("$@")
        local eza_cmd=("eza" "--git" "-F" "-h" "-B" "--color=always")
        local options=() arguments=()
        local has_t=false has_r=false

        for arg in "${cmd[@]}"; do
            if [[ "${arg}" == --* ]]; then
                options+=("${arg}")
            elif [[ "${arg}" == -* ]]; then
                for ((i = 1; i < ${#arg}; i++)); do
                    options+=("-${arg:i:1}")
                done
            else
                arguments+=("${arg}")
            fi
        done

        for opt in "${options[@]}"; do
            case "${opt}" in
                -l) eza_cmd+=("-l" "--group") ;;
                -t)
                    eza_cmd+=("--sort=modified")
                                                  has_t=true
                                                             ;;
                -S) eza_cmd+=("--sort=size") ;;
                -F) eza_cmd+=("--classify") ;;
                -r) has_r=true ;;
                *) eza_cmd+=("${opt}") ;;
            esac
        done

        if [[ "${has_t}" == true || "${has_r}" == true ]]; then
            eza_cmd+=("--reverse")
        fi

        eza_cmd+=("${arguments[@]}")
        "${eza_cmd[@]}"
    }

    ###############################################################################
    # _Pause
    #------------------------------------------------------------------------------
    # Purpose  : Pause execution until a key is pressed.
    ###############################################################################
    function _Pause() {
        info "Press any key to continue..."
        read -r -n 1 -s
        if command -v tput > /dev/null 2>&1; then
            tput cuu 3
            tput el
            tput el
            tput el
        fi
    }

    ###############################################################################
    # get_session_name
    #------------------------------------------------------------------------------
    # Purpose  : Retrieve TMUX or SCREEN session names, if active.
    ###############################################################################
    function get_session_name() {
        local session_names=()
        if [[ -n "${TMUX:-}" ]]; then
            session_names+=("TMUX:$(tmux display-message -p '#S')")
        fi
        if [[ -n "${STY:-}" ]]; then
            local screen_session
            screen_session="$(printf '%s\n' "${STY}" | awk -F '.' '{print $2}')"
            session_names+=("SCREEN:${screen_session}")
        fi
        if [[ ${#session_names[@]} -gt 0 ]]; then
            printf '%s\n' "${session_names[*]// /, }"
        fi
    }

    ###############################################################################
    # sort_first
    #------------------------------------------------------------------------------
    # Purpose  : Sorts hashes in a file (unique, natural order).
    # Usage    : sort_first <file...>
    ###############################################################################
    function sort_first() {
        sort -Vfu "$@" | sort -t: -k1,3 -fu
    }

    ###############################################################################
    # ss
    #------------------------------------------------------------------------------
    # Purpose  : Capture command, piped output, or clipboard text as a PNG screenshot
    #            using Charmbracelet's 'freeze' renderer.
    # Usage    :
    #   cat file.txt | ss
    #   ls -lart | ss
    #   ss "ls -lart"
    #   ss -l go "cat main.go"
    #   ss -c
    #   ss -c -l python
    # Arguments:
    #   -l : Language for syntax highlighting (default: ansi)
    #   -c : Capture clipboard contents
    # Returns  : PASS (0) if screenshot saved, FAIL (1) otherwise.
    # Globals  : PASS, FAIL
    # Requires : freeze, stty, tput, pbpaste/xclip/wl-paste
    ###############################################################################
    function ss() {
        local width ts outfile language="ansi" clipboard=false opt
        local -a cmd_args
        # local OPTIND to avoid clobbering caller's OPTIND and to ensure reset
        local OPTIND
        OPTIND=1

        #============================================================================
        # Parse options
        #============================================================================
        while getopts ":l:c" opt; do
            case "${opt}" in
                l)
                    language="${OPTARG}"
                    ;;
                c)
                    clipboard=true
                    ;;
                :)
                    error "Option -${OPTARG} requires an argument."
                    return "${FAIL}"
                    ;;
                \?)
                    error "Invalid option: -${OPTARG}"
                    return "${FAIL}"
                    ;;
                *)  ;;
            esac
        done
        shift $((OPTIND - 1))
        cmd_args=("$@")

        #============================================================================
        # Validate dependencies
        #============================================================================
        if ! command -v freeze > /dev/null 2>&1; then
            error "'freeze' not found in PATH. Install with:"
            error "    go install github.com/charmbracelet/freeze@latest"
            return "${FAIL}"
        fi

        #============================================================================
        # Determine terminal width safely
        #============================================================================
        if [[ -t 0 ]]; then
            width="$(stty size 2> /dev/null | awk '{print $2}')"
        else
            width="$(tput cols 2> /dev/null || printf '%s' 120)"
        fi
        if [[ -z "${width}" || "${width}" -lt 40 ]]; then
            width=120
        fi

        ts="$(date '+%Y-%m-%d_%H-%M-%S')"
        outfile="ss_${ts}.png"

        #============================================================================
        # Clipboard capture mode
        #============================================================================
        if [[ "${clipboard}" == true ]]; then
            local os
            os="$(_get_os)"

            case "${os}" in
                macos)
                    if command -v pbpaste > /dev/null 2>&1; then
                        clipboard_source="pbpaste"
                    fi
                    ;;
                ubuntu | linux | wsl)
                    if command -v wl-paste > /dev/null 2>&1; then
                        clipboard_source="wl-paste"
                    elif command -v xclip > /dev/null 2>&1; then
                        clipboard_source="xclip -selection clipboard -o"
                    fi
                    ;;
                *)  ;;
            esac

            if [[ -z "${clipboard_source}" ]]; then
                error "No clipboard utility found (requires pbpaste, wl-paste, or xclip)."
                return "${FAIL}"
            fi

            info "Capturing clipboard contents..."
            freeze \
                --language "${language}" \
                --wrap "${width}" \
                --background "#000000" \
                --margin 0 \
                --padding 20 \
                --output "${outfile}" \
                --execute "${clipboard_source}"

        #============================================================================
        # Command execution mode (using --execute)
        #============================================================================
        elif [[ -t 0 ]]; then
            if [[ "${#cmd_args[@]}" -eq 0 ]]; then
                warn "Usage: ss [-l <language>] [-c] \"<command>\"  OR  <cmd> | ss"
                return "${FAIL}"
            fi

            info "Executing command with freeze: ${cmd_args[*]}"
            freeze \
                --language "${language}" \
                --wrap "${width}" \
                --background "#000000" \
                --margin 0 \
                --padding 20 \
                --output "${outfile}" \
                --execute "${cmd_args[*]}"

        #============================================================================
        # Piped input mode
        #============================================================================
        else
            freeze \
                --language "${language}" \
                --wrap "${width}" \
                --background "#000000" \
                --margin 0 \
                --padding 20 \
                --output "${outfile}"
        fi

        #============================================================================
        # Verify output file
        #============================================================================
        if [[ -f "${outfile}" ]]; then
            info "Screenshot saved as: ${outfile}"
            return "${PASS}"
        else
            error "Output file not found: ${outfile}"
            return "${FAIL}"
        fi
    }
fi
