#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# NAME        : tmux.aliases.sh
# DESCRIPTION :
# AUTHOR      : Adam Compton
# DATE CREATED: 2024-12-08 19:57:22
# =============================================================================
# EDIT HISTORY:
# DATE                 | EDITED BY    | DESCRIPTION OF CHANGE
# ---------------------|--------------|----------------------------------------
# 2024-12-08 19:57:22  | Adam Compton | Initial creation.
# =============================================================================

# Guard to prevent multiple sourcing
if [[ -z "${TMUX_ALIAS_SH_LOADED:-}" ]]; then
    declare -g TMUX_ALIAS_SH_LOADED=true

    # ------------------------------------------- #
    #####
    ########## TMUX UTILITY FUNCTIONS ##########
    #####
    # ------------------------------------------- #

    function tmux() {
        debug "\$@=" "$@"

        # Initialize variables
        local session_name=""
        local args=()

        # Parse arguments to find "new -s <session_name>"
        while [[ $# -gt 0 ]]; do
            case "$1" in
                new)
                    args+=("$1")
                    shift
                    if [[ "$1" == "-s" && -n "$2" ]]; then
                        session_name="$2"
                        args+=("$1" "$2")
                        shift 2
                    else
                        fail "'new' requires '-s <session_name>'" >&2
                        return 1
                    fi
                    ;;
                *)
                    args+=("$1")
                    shift
                    ;;
            esac
        done

        # If -S <session_name> was found, handle tmux session creation or attachment
        if [[ -n "${session_name}" ]]; then
            if does_tmux_session_exist "${session_name}"; then
                info "Attaching to session [${session_name}]"
                command tmux attach -t "${session_name}" "${args[@]}"
            else
                local timestamp
                timestamp=$(date +"%Y%m%d_%H%M%S")

                local logfile_path
                log_file="${HOME}/DATA/LOGS/${session_name}.${timestamp}.tmux"

                mkdir -p "${HOME}/DATA/LOGS"

                info "Starting session [${session_name}]"
                command tmux new -s "${session_name}" -d "${args[@]}"
                command tmux set-option -t "${session_name}" -g monitor-activity on
                command tmux pipe-pane -t "${session_name}" -o "exec cat >> ${log_file}"
                command tmux attach -t "${session_name}"
            fi
        else
            # Default behavior for other tmux commands
            command tmux "${args[@]}"
        fi
    }

    # Create a tmux session with logging
    function tmuxS() {
        local session_name="$1"
        local log_file="${LOGS_DIR}/${session_name}.tmux"

        if does_tmux_session_exist "${session_name}"; then
            tmux attach -t "${session_name}"
        else
            info "Starting session [${session_name}]"
            tmux new -s "${session_name}" -d
            tmux set-option -t "${session_name}" -g monitor-activity on
            tmux pipe-pane -t "${session_name}" -o "exec cat >> ${log_file}"
            tmux attach -t "${session_name}"
        fi
    }

    # Return a list of tmux sessions
    function get_tmux_session_list() {
        tmux list-sessions -F '#{session_name}'
    }

    # Verify if a given session exists
    # ARG1 = session name
    function does_tmux_session_exist() {
        local sess="$1"
        if [[ -z "${sess}" ]]; then
            echo "${FUNCNAME[0]} - Session name not provided"
            return 1
        fi

        for temp_session in $(get_tmux_session_list); do
            if [[ "${temp_session}" == "${sess}" ]]; then
                return 0 # Session exists
            fi
        done
        return 1 # Session does not exist
    }

    # Execute a command on a given session
    # ARG 1 = session to execute on
    # ARG 2 = command to execute
    function exec_cmd_in_tmux_session() {
        local session="$1"
        local cmd="$2"

        echo "Executing: [${cmd}] on session [${session}]"
        if does_tmux_session_exist "${session}"; then
            tmux send-keys -t "${session}" "${cmd}" Enter
            pass ""
        else
            info "Session [${session}] does not exist!"
        fi
    }

    # Loop over all sessions and run a specified command
    # ARG 1 = command to execute
    function exec_on_all_tmux_sessions() {
        local cmd="$1"
        for session in $(get_tmux_session_list); do
            exec_cmd_in_tmux_session "${session}" "${cmd}"
        done
    }

    # Create a new session in a specified directory
    # ARG 1 = session name
    # ARG 2 = directory to start in
    function create_tmux_session() {
        local session="$1"
        local directory="$2"

        if [[ -z "${session}" || -z "${directory}" ]]; then
            echo "${FUNCNAME[0]} - Session name or directory not provided"
            return
        fi

        if does_tmux_session_exist "${session}"; then
            fail "Session [${session}] already exists"
            return
        fi

        if [[ ! -d "${directory}" ]]; then
            warn "Directory [${directory}] does not exist"
            info "Creating directory [${directory}]"
            mkdir -p "${directory}" || {
                fail "Directory [${directory}] could not be created"
                return
            }
        fi

        info "Starting session [${session}]"
        tmux new -s "${session}" -d -c "${directory}"
        pass "Tmux session [${session}] successfully created"
    }

    # Interactive selection of a tmux session
    function t() {
        PS3="Select an Option: "
        select session_name in $(get_tmux_session_list); do
            if [[ -n "${session_name}" ]]; then
                tmuxS "${session_name}"
                break
            else
                echo "Invalid selection"
            fi
        done
    }
fi
