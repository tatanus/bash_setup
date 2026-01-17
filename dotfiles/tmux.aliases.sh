#!/usr/bin/env bash
# shellcheck disable=SC2154 # LOGS_DIR is set by user's environment
# shellcheck disable=SC2034 # Variables may be used externally
set -uo pipefail
IFS=$'\n\t'

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

    ###############################################################################
    # tmux
    #------------------------------------------------------------------------------
    # Purpose  : Wrapper for tmux with logging support for new sessions
    # Usage    : tmux [new -s session_name] [options]
    # Arguments:
    #   Passes through all arguments to tmux command
    # Returns  : tmux exit code
    ###############################################################################
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

    ###############################################################################
    # tmuxS
    #------------------------------------------------------------------------------
    # Purpose  : Create or attach to a tmux session with logging enabled
    # Usage    : tmuxS <session_name>
    # Arguments:
    #   $1 : session_name - Name of the tmux session
    # Returns  : 0 on success
    ###############################################################################
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

    ###############################################################################
    # does_tmux_session_exist
    #------------------------------------------------------------------------------
    # Purpose  : Check if a given tmux session exists
    # Usage    : does_tmux_session_exist <session_name>
    # Arguments:
    #   $1 : session_name - Name of the tmux session to check
    # Returns  : 0 if exists, 1 if not found
    ###############################################################################
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

    ###############################################################################
    # exec_cmd_in_tmux_session
    #------------------------------------------------------------------------------
    # Purpose  : Execute a command in a specific tmux session
    # Usage    : exec_cmd_in_tmux_session <session> <cmd>
    # Arguments:
    #   $1 : session - Name of the tmux session
    #   $2 : cmd - Command to execute
    # Returns  : 0 on success
    ###############################################################################
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

    ###############################################################################
    # exec_on_all_tmux_sessions
    #------------------------------------------------------------------------------
    # Purpose  : Execute a command on all active tmux sessions
    # Usage    : exec_on_all_tmux_sessions <cmd>
    # Arguments:
    #   $1 : cmd - Command to execute on all sessions
    # Returns  : 0 on completion
    ###############################################################################
    function exec_on_all_tmux_sessions() {
        local cmd="$1"
        for session in $(get_tmux_session_list); do
            exec_cmd_in_tmux_session "${session}" "${cmd}"
        done
    }

    ###############################################################################
    # create_tmux_session
    #------------------------------------------------------------------------------
    # Purpose  : Create a new tmux session in a specified directory
    # Usage    : create_tmux_session <session_name> <directory>
    # Arguments:
    #   $1 : session_name - Name for the new session
    #   $2 : directory - Directory to start the session in
    # Returns  : 0 on success, 1 on error
    ###############################################################################
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

    ###############################################################################
    # t
    #------------------------------------------------------------------------------
    # Purpose  : Interactive menu to select and attach to a tmux session
    # Usage    : t
    # Returns  : 0 on success
    ###############################################################################
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
