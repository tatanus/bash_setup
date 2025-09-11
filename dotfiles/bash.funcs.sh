#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# NAME        : bash.funcs.sh
# DESCRIPTION : A collection of useful functions for Bash.
# AUTHOR      : Adam Compton
# DATE CREATED: 2024-12-08 19:57:22
# =============================================================================
# EDIT HISTORY:
# DATE                 | EDITED BY    | DESCRIPTION OF CHANGE
# ---------------------|--------------|----------------------------------------
# 2024-12-08 19:57:22  | Adam Compton | Initial creation.
# =============================================================================

# Guard to prevent multiple sourcing
if [[ -z "${BASH_FUNCS_SH_LOADED:-}" ]]; then
    declare -g BASH_FUNCS_SH_LOADED=true

    ###############################################################################
    # history_search
    #==============================
    # Searches ~/.config/bash/log/bash_history.log for entries within ±N minutes
    # of a given timestamp.
    #
    # Globals:
    #   BASH_LOG_DIR
    #
    # Usage:
    #   history_search "YYYY-MM-DD HH:MM:SS" [range_minutes]
    #
    # Returns:
    #   Prints matching log lines to stdout.
    #   1 on error.
    ###############################################################################
    function history_search() {
        local input_time="${1:-}"
        local range_minutes="${2:-10}"
        local log_file

        if [[ -z "${BASH_LOG_DIR:-}" ]]; then
            log_file="${HOME}/.combined_history.log"
        else
            log_file="${BASH_LOG_DIR}/bash_history.log"
        fi

        # Validate required input
        if [[ -z "${input_time}" ]]; then
            fail "Usage: history_search \"YYYY-MM-DD HH:MM:SS\" [range_minutes]"
            return 1
        fi

        if [[ ! -f "${log_file}" ]]; then
            error "Log file not found: ${log_file}"
            return 1
        fi

        # Validate timestamp format
        local target_epoch
        if ! target_epoch=$(date -d "${input_time}" +%s 2> /dev/null); then
            fail "Invalid timestamp format. Use YYYY-MM-DD HH:MM:SS"
            return 1
        fi

        local range_seconds=$((range_minutes * 60))
        local start_epoch=$((target_epoch - range_seconds))
        local end_epoch=$((target_epoch + range_seconds))

        # Search lines within time window
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
    #==============================
    # Detects the current operating system.
    #
    # Returns:
    #   One of: macos, ubuntu, wsl, windows, linux, unknown
    ###############################################################################
    function _get_os() {
        local uname_output
        uname_output="$(uname -s)"

        if [[ "${uname_output}" == "Darwin" ]]; then
            echo "macos"
            return
        fi
        if grep -qi Microsoft /proc/version 2> /dev/null; then
            echo "wsl"
            return
        fi
        case "${uname_output}" in
            CYGWIN* | MINGW* | MSYS*)
                echo "windows"
                return
                ;;
            *)
                # No action
                ;;

        esac
        if [[ "${uname_output}" == "Linux" ]]; then
            if [[ -f /etc/os-release ]] && grep -qi "ubuntu" /etc/os-release; then
                echo "ubuntu"
                return
            fi
            echo "linux"
            return
        fi
        echo "unknown"
    }

    ###############################################################################
    # _get_macos_version
    #==============================
    # Retrieves macOS version using `sw_vers -productVersion`.
    #
    # Returns:
    #   Version string on success, 1 on failure.
    ###############################################################################
    function _get_macos_version() {
        if [[ "$(_get_os)" != "macos" ]]; then
            fail "Not running on macOS."
            return 1
        fi
        if ! command -v sw_vers &> /dev/null; then
            fail "Missing sw_vers command. Cannot detect macOS version."
            return 1
        fi
        local macos_version
        macos_version="$(sw_vers -productVersion 2> /dev/null || true)"
        if [[ -z "${macos_version}" ]]; then
            fail "Could not retrieve macOS version."
            return 1
        fi
        echo "${macos_version}"
    }

    ###############################################################################
    # _get_ubuntu_version
    #==============================
    # Retrieves Ubuntu version from /etc/os-release or lsb_release.
    #
    # Returns:
    #   Version string on success, 1 on failure.
    ###############################################################################
    function _get_ubuntu_version() {
        if [[ "$(_get_os)" != "ubuntu" ]]; then
            fail "Not running on Ubuntu."
            return 1
        fi
        local ubuntu_version=""
        if [[ -f /etc/os-release ]]; then
            ubuntu_version="$(grep -oP 'VERSION_ID="\K[^"]+' /etc/os-release || true)"
        elif command -v lsb_release &> /dev/null; then
            ubuntu_version="$(lsb_release -rs 2> /dev/null || true)"
        fi
        if [[ -z "${ubuntu_version}" ]]; then
            fail "Unable to determine Ubuntu version."
            return 1
        fi
        echo "${ubuntu_version}"
    }

    ###############################################################################
    # _get_windows_version
    #==============================
    # Retrieves Windows version using `cmd.exe /c ver`.
    #
    # Returns:
    #   Version string on success, 1 on failure.
    ###############################################################################
    function _get_windows_version() {
        local current_os
        current_os="$(_get_os)"

        if [[ "${current_os}" != "windows" ]]; then
            fail "Not running on Windows (Cygwin/Mingw/MSYS)."
            return 1
        fi
        if ! command -v cmd.exe &> /dev/null; then
            fail "cmd.exe not found. Cannot detect Windows version."
            return 1
        fi
        local ver_output
        ver_output="$(cmd.exe /c "ver" 2> /dev/null || true)"
        local windows_version
        windows_version="$(echo "${ver_output}" | grep -oP '\[Version\s\K[^\]]+' || true)"
        if [[ -z "${windows_version}" ]]; then
            fail "Could not retrieve Windows version from cmd.exe."
            return 1
        fi
        echo "${windows_version}"
    }

    ###############################################################################
    # _get_linux_version
    #==============================
    # Retrieves Linux version (if generic Linux).
    #
    # Returns:
    #   Version string, or empty string if unknown.
    ###############################################################################
    function _get_linux_version() {
        if [[ "$(_get_os)" != "linux" ]]; then
            echo ""
            return 0
        fi
        [[ -f /etc/os-release ]] || {
                                      echo ""
                                               return 0
        }
        grep -oP 'VERSION_ID="\K[^"]+' /etc/os-release || true
    }

    ###############################################################################
    # check_command
    #==============================
    # Checks for a required command and suggests installation if missing.
    #
    # Returns:
    #   0 if found, 1 if missing.
    ###############################################################################
    function check_command() {
        local cmd
        cmd="$1"

        if ! command -v "${cmd}" &> /dev/null; then
            local os
            os="$(_get_os)"

            local install_hint
            case "${os}" in
                macos) install_hint="brew install ${cmd}" ;;
                ubuntu | wsl) install_hint="sudo apt-get install ${cmd}" ;;
                *) install_hint="(install ${cmd} manually)" ;;
            esac
            warn "[${cmd}] is not installed. Suggested: ${install_hint}"
            return 1
        fi
    }

    ###############################################################################
    # convert_ls_to_eza
    #==============================
    # Converts ls command to equivalent eza command with options.
    ###############################################################################
    function convert_ls_to_eza() {
        local cmd=("$@")
        local eza_cmd=("eza" "--git" "-F" "-h" "-B")
        local options=()
        local arguments=()

        # Parse args
        for arg in "${cmd[@]}"; do
            if [[ ${arg} == --* ]]; then
                options+=("${arg}")
            elif [[ ${arg} == -* ]]; then
                for ((i = 1; i < ${#arg}; i++)); do
                    options+=("-${arg:i:1}")
                done
            else
                arguments+=("${arg}")
            fi
        done

        local has_t=false
        local has_r=false
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

        if [[ "${has_t}" == true && "${has_r}" == true ]]; then
            :
        elif [[ "${has_t}" == true ]]; then
            eza_cmd+=("--reverse")
        elif [[ "${has_r}" == true ]]; then
            eza_cmd+=("--reverse")
        fi

        eza_cmd+=("${arguments[@]}")
        "${eza_cmd[@]}"
    }

    ###############################################################################
    # _Pause
    #==============================
    # Pause execution until a key is pressed.
    ###############################################################################
    function _Pause() {
        info "Press any key to continue..."
        read -n 1 -s -r
        if command -v tput &> /dev/null; then
            tput cuu 3
                        tput el
                                 tput el
                                          tput el
        fi
    }

    ###############################################################################
    # get_session_name
    #==============================
    # Retrieves TMUX or SCREEN session names.
    ###############################################################################
    function get_session_name() {
        local session_names=()
        if [[ -n "${TMUX:-}" ]]; then
            session_names+=("TMUX:$(tmux display-message -p '#S')")
        fi
        if [[ -n "${STY:-}" ]]; then
            local screen_session
            screen_session=$(echo "${STY}" | awk -F '.' '{print $2}')
            session_names+=("SCREEN:${screen_session}")
        fi
        [[ ${#session_names[@]} -gt 0 ]] && echo "${session_names[*]// /, }"
    }

    ###############################################################################
    # sort_first
    #==============================
    # Sorts hashes in a file (unique, natural order).
    ###############################################################################
    function sort_first() {
        sort -Vfu "$@" | sort -t: -k1,3 -fu
    }
fi
