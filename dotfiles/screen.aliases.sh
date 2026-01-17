#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

# =============================================================================
# NAME        : screen.aliases.sh
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
if [[ -z "${SCREEN_ALIAS_AH_LOADED:-}" ]]; then
    declare -g SCREEN_ALIAS_AH_LOADED=true

    # Function to determine the appropriate log file path
    function get_logfile_path() {
        local log_filename="$1"

        echo "${HOME}/DATA/LOGS/${log_filename}"
    }

    # ------------------------------------------- #
    #####
    ########## GNU SCREEN UTILITY FUNCTIONS ##########
    #####
    # ------------------------------------------- #

    ###############################################################################
    # screen
    #------------------------------------------------------------------------------
    # Purpose  : Wrapper for GNU screen with logging support
    # Usage    : screen [-S session_name] [options]
    # Arguments:
    #   -S : session_name - Name for the screen session
    # Returns  : 0 on success
    ###############################################################################
    function screen() {
        # Initialize variables
        local session_name=""
        local args=()

        # Parse arguments to find "-S <session_name>"
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -S)
                    if [[ -n "$2" ]]; then
                        session_name="$2"
                        shift 2
                    else
                        fail "-S flag requires a session name" >&2
                        return 1
                    fi
                    ;;
                *)
                    args+=("$1")
                    shift
                    ;;
            esac
        done

        # If -S <session_name> was found, start a logged screen session
        if [[ -n "${session_name}" ]]; then
            command screen -S "${session_name}" "${args[@]}"
        else
            # Default behavior if -S <session_name> is not found
            command screen "${args[@]}"
        fi
    }

    function get_screen_session_list() {
        # This function returns a list of all active screen sessions.
        # It uses the "screen -ls" command to list all screen sessions,
        # and then filters the output to extract the session names.
        # Usage: get_screen_session_list
        screen -ls | grep tached | awk '{ print $1 }'
    }

    ###############################################################################
    # does_screen_session_exist
    #------------------------------------------------------------------------------
    # Purpose  : Check if a given screen session exists
    # Usage    : does_screen_session_exist <session_name>
    # Arguments:
    #   $1 : session_name - Name of the screen session to check
    # Returns  : 0 if session exists, 1 if not found or error
    ###############################################################################
    function does_screen_session_exist() {
        # This function checks if a given screen session exists.
        # It takes one argument:
        # - sess: The name of the screen session to check.
        # It iterates over all active screen sessions and compares the session names.
        # If a match is found, it returns 0 (session exists), otherwise it returns 1 (session does not exist).
        # Usage: does_screen_session_exist <session_name>
        local sess="$1"
        if [[ -z "${sess}" ]]; then
            warn"${FUNCNAME[0]} - Session name not provided"
            return 1
        fi

        for temp_session in $(get_screen_session_list); do
            if [[ "${temp_session}" == "${sess}" ]]; then
                return 0 # Session exists
            fi
        done
        return 1 # Session does not exist
    }

    ###############################################################################
    # exec_cmd_in_screen_session
    #------------------------------------------------------------------------------
    # Purpose  : Execute a command in a specific screen session
    # Usage    : exec_cmd_in_screen_session <session> <cmd>
    # Arguments:
    #   $1 : session - Name of the screen session
    #   $2 : cmd - Command to execute
    # Returns  : 0 on success
    ###############################################################################
    function exec_cmd_in_screen_session() {
        # This function executes a command on a given screen session.
        # It takes two arguments:
        # - session: The name of the screen session to execute the command on.
        # - cmd: The command to execute.
        # It checks if the screen session exists, and if it does, it sends the command to the session using the "screen -X stuff" command.
        # Usage: exec_cmd_in_screen_session <session> <cmd>
        local session="$1"
        local cmd="$2"

        info "Executing: [${cmd}] on session [${session}]"
        if does_screen_session_exist "${session}"; then
            screen -S "${session}" -X stuff "${cmd}$(echo -ne '\015')"
            pass ""
        else
            warn "Session [${session}] does not exist!"
        fi
    }

    ###############################################################################
    # exec_on_all_screen_sessions
    #------------------------------------------------------------------------------
    # Purpose  : Execute a command on all active screen sessions
    # Usage    : exec_on_all_screen_sessions <cmd>
    # Arguments:
    #   $1 : cmd - Command to execute on all sessions
    # Returns  : 0 on completion
    ###############################################################################
    function exec_on_all_screen_sessions() {
        # This function executes a specified command on all active screen sessions.
        # It takes one argument:
        # - cmd: The command to execute.
        # It retrieves the list of all active screen sessions using the "get_screen_session_list" function,
        # and then calls the "exec_cmd_in_screen_session" function for each session.
        # Usage: exec_on_all_screen_sessions <cmd>
        local cmd="$1"
        for session in $(get_screen_session_list); do
            exec_cmd_in_screen_session "${session}" "${cmd}"
        done
    }

    # Function to get the command running for a given PID and its child processes recursively
    function _get_pid_commands() {
        local pid="$1"

        # Validate input PID and check if the process exists
        #if [[ -z "${pid}" || ! -n $(ps -p "${pid}") ]]; then
        if [[ -z "${pid}" ]] || ! ps -p "${pid}" &> /dev/null; then
            info "Usage: get_commands <pid>" && return 1
            return 1
        fi

        local window_index=0
        local commands=()

        ###############################################################################
        # find_leaves
        #------------------------------------------------------------------------------
        # Purpose  : Recursively find leaf processes and capture their commands
        # Usage    : find_leaves <pid>
        # Arguments:
        #   $1 : pid - Process ID to start from
        # Returns  : Populates commands array with leaf process commands
        ###############################################################################
        function find_leaves() {
            local p="$1"
            local children=()
            mapfile -t children < <(pgrep -P "${p}")

            # If no children, it's a leaf process, so capture its command
            if [[ ${#children[@]} -eq 0 ]]; then
                local command
                command=$(ps -p "${p}" -o args= 2> /dev/null)
                [[ -n "${command}" ]] && commands+=("${command}")
            else
                # Recursively find leaves of child processes
                for child in "${children[@]}"; do
                    find_leaves "${child}"
                done
            fi
        }

        # Get all child processes of the input PID
        local children=()
        mapfile -t children < <(pgrep -P "${pid}")

        if [[ ${#children[@]} -eq 0 ]]; then
            echo "No child processes found for PID ${pid}."
            return 0
        fi

        # For each child, find its leaf processes and print the commands
        for child in "${children[@]}"; do
            find_leaves "${child}"
            if [[ ${#commands[@]} -gt 0 ]]; then
                printf 'WINDOW %d: %s\n' "${window_index}" "${commands[*]}"
                ((window_index++))
                commands=() # Reset commands for the next window
            fi
        done

        # If no windows were printed, indicate no child processes were found
        [[ ${window_index} -eq 0 ]] && echo "No child processes found with leaf commands."
    }

    # Export the get_commands function for use in subshells
    export -f _get_pid_commands

    ###############################################################################
    # truncate_string
    #------------------------------------------------------------------------------
    # Purpose  : Truncate a string to a specified maximum length
    # Usage    : truncate_string <string> [max_length]
    # Arguments:
    #   $1 : string - The string to truncate
    #   $2 : max_length - Maximum length (default: 63)
    # Returns  : Prints truncated string to stdout
    ###############################################################################
    function truncate_string() {
        local str="$1"
        local max="${2:-63}"
        local len="${#str}"

        if ((len > max)); then
            echo "${str:0:$((max - 3))}..."
        else
            echo "${str}"
        fi
    }

    ###############################################################################
    # show_all_screen_commands_and_select
    #------------------------------------------------------------------------------
    # Purpose  : Display commands in all screen sessions and allow selection
    # Usage    : show_all_screen_commands_and_select
    # Returns  : 0 on success, 1 if no sessions found
    ###############################################################################
    function show_all_screen_commands_and_select() {
        # Capture the list of active screen sessions
        IFS=$'\n' read -r -d '' -a session_list < <(get_screen_session_list && printf '\0')

        if [[ ${#session_list[@]} -eq 0 ]]; then
            echo "No active screen sessions found."
            return 1
        fi

        info "Current Screen Sessions:"

        # Use fzf to select a session with a preview of commands
        local selected_session
        # shellcheck disable=SC2016
        selected_session=$(
            printf "%s\n" "${session_list[@]}" | fzf \
                --prompt="Select a screen session: " \
                --no-clear \
                --preview 'bash -c "echo \"== Commands for Screen Session -- $(echo {1}) ==\"; echo; _get_pid_commands $(echo {1} | cut -d . -f 1)"' \
                --preview-window=down:10:wrap:sharp
        )

        # Handle the case where no session was selected
        if [[ -n "${selected_session}" ]]; then
            # Extract the session name (before the dot) and attach to it
            local selected_session_name
            selected_session_name=$(echo "${selected_session}" | cut -d '.' -f 1)
            screen -x "${selected_session_name}"
        else
            warn "No session selected. Exiting."
        fi
    }

    function s() {
        show_all_screen_commands_and_select
    }
fi
